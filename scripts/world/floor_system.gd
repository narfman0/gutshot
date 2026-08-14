## Multi-floor reveal state — Phase 2's vertical tech (docs/plan.md).
##
## The camera keeps its continuous follow; the thing that "transitions" when
## the player changes floors is the REVEAL STATE: floors at or below the
## active floor render solid, the floor directly above materializes across
## the last stretch of the climb toward it (per-instance fade via
## GeometryInstance3D.transparency), and anything higher stays hidden — a
## closed-off top floor is unknown until you take the stairs.
##
## Rendering-only: LOS raycasts, AI, and audio never consult this. A fight
## on a hidden floor still plays out — you hear it, you don't watch it.
class_name FloorSystem
extends Node

## The floor above materializes across the last quarter of the climb: hidden
## below 75% of the vertical rise, fully solid by 95%.
const REVEAL_START := 0.75
const REVEAL_END := 0.95
## Hysteresis: commit UP near the top of the stairs; revert DOWN only well
## below the slab — idling mid-flight can't flicker the state.
const COMMIT_UP_T := 0.9
const COMMIT_DOWN_T := 0.6
## Eased application rate (per second) — absorbs the pops the climb ramp
## can't cover: hysteresis flips, falls off edges, character floor changes.
const FADE_SPEED := 5.0
## Geometry whose center sits within this slack below a floor plane still
## belongs to that floor (slabs are built just under their walk height).
const ASSIGN_SLACK := 0.4
## The reveal logic engages a little OUTSIDE the site too, so approaching
## the walls already hides the floors that would occlude the doorway.
const BOUNDS_MARGIN := 6.0

var heights: Array = []
var active_floor := 0
## World-space XZ footprint of the site this system owns — in the seamless
## district several FloorSystems coexist, each scoped to its own chunk.
var bounds: Rect2

var _squad: Squad
var _geometry: Array = []  # per floor: Array[GeometryInstance3D]
var _lights: Array = []    # per floor: Array[[Light3D, original energy]]
var _display: Array = []   # per floor: opacity actually applied
var _hidden: Array = []    # characters this system set invisible last frame

## Bucket every GeometryInstance3D and Light3D under `level_root` by height.
## Assignment is automatic — an object belongs to the highest floor plane its
## center sits on (with slack), so slabs, railings, and per-floor practicals
## need no manual grouping. Stairs center on the floor they rise FROM: the
## route up is visible before the destination is.
func setup(squad: Squad, level_root: Node3D, floor_heights: Array,
		site_bounds: Rect2) -> void:
	_squad = squad
	heights = floor_heights
	bounds = site_bounds
	for i in heights.size():
		_geometry.append([])
		_lights.append([])
		# Buildings start WHOLE — the crew is normally elsewhere in the
		# district; the reveal logic takes over the moment they step inside.
		_display.append(1.0)
	for gi: GeometryInstance3D in level_root.find_children("*", "GeometryInstance3D", true, false):
		_geometry[floor_of_y(gi.global_position.y)].append(gi)
	for light: Light3D in level_root.find_children("*", "Light3D", true, false):
		_lights[floor_of_y(light.global_position.y)].append([light, light.light_energy])
	for i in heights.size():
		_apply(i, _display[i])

func floor_of_y(y: float) -> int:
	for i in range(heights.size() - 1, 0, -1):
		if y >= heights[i] - ASSIGN_SLACK:
			return i
	return 0

## Displayed opacity of a floor (harness probe).
func opacity(floor_idx: int) -> float:
	return _display[floor_idx]

## Vertical progress [0..1] from the active floor toward the next one up.
func climb_t(y: float) -> float:
	if active_floor >= heights.size() - 1:
		return 0.0
	var h0: float = heights[active_floor]
	var h1: float = heights[active_floor + 1]
	return clampf((y - h0) / (h1 - h0), 0.0, 1.0)

func _process(delta: float) -> void:
	if _squad == null:
		return
	var active := _squad.active_character()
	if active == null or not is_instance_valid(active):
		return
	# Crew elsewhere in the district → the building stands whole from outside.
	var inside := bounds.grow(BOUNDS_MARGIN).has_point(
		Vector2(active.global_position.x, active.global_position.z))
	if inside:
		_update_active_floor(active.global_position.y)
	for i in heights.size():
		var target := 1.0
		if inside:
			target = 0.0
			if i <= active_floor:
				target = 1.0
			elif i == active_floor + 1:
				target = smoothstep(REVEAL_START, REVEAL_END,
					climb_t(active.global_position.y))
		var shown := move_toward(_display[i], target, FADE_SPEED * delta)
		if not is_equal_approx(shown, _display[i]):
			_display[i] = shown
			_apply(i, shown)
	_update_characters(inside)

func _update_active_floor(y: float) -> void:
	while active_floor < heights.size() - 1 and climb_t(y) >= COMMIT_UP_T:
		active_floor += 1
	# Loops so a fall across several floors resolves in one frame.
	while active_floor > 0:
		var h0: float = heights[active_floor - 1]
		var h1: float = heights[active_floor]
		if (y - h0) / (h1 - h0) > COMMIT_DOWN_T:
			break
		active_floor -= 1

func _apply(floor_idx: int, floor_opacity: float) -> void:
	for gi in _geometry[floor_idx]:
		if is_instance_valid(gi):
			gi.visible = floor_opacity > 0.001
			gi.transparency = 1.0 - floor_opacity
	for entry in _lights[floor_idx]:
		var light := entry[0] as Light3D
		if is_instance_valid(light):
			light.visible = floor_opacity > 0.001
			light.light_energy = entry[1] * floor_opacity

## Characters ONE floor above are drawn only while some living crew member
## actually has a line on them — the mezzanine overlook fight (guards firing
## down over a railing) stays readable from below, but a guard tucked behind
## the deck isn't rendered floating in the dark. Crew are always drawn up to
## one floor above; deeper floors hide everyone with the geometry. Scoped to
## THIS site's bounds; anyone we hid who is no longer covered by the rule
## (left the site, or the crew left) is released visible.
func _update_characters(inside: bool) -> void:
	var still_hidden: Array = []
	if inside:
		var grown := bounds.grow(BOUNDS_MARGIN)
		var crew := get_tree().get_nodes_in_group("team_0")
		for node in get_tree().get_nodes_in_group("characters"):
			var c := node as Character
			if c == null or not is_instance_valid(c):
				continue
			if not grown.has_point(Vector2(c.global_position.x, c.global_position.z)):
				continue  # someone else's site — not this system's call
			var floor_idx := floor_of_y(c.global_position.y)
			var show := true
			if floor_idx <= active_floor or c.team == 0:
				show = floor_idx <= active_floor + 1
			elif floor_idx == active_floor + 1:
				show = _crew_sees(c, crew)
			else:
				show = false
			c.visible = show
			if not show:
				still_hidden.append(c)
	for c in _hidden:
		if is_instance_valid(c) and not still_hidden.has(c):
			(c as Character).visible = true
	_hidden = still_hidden

func _crew_sees(target: Character, crew: Array) -> bool:
	for node in crew:
		var member := node as Character
		if member != null and member.is_alive() \
				and Cover.exposure(member.muzzle_position(), target) > Cover.FULL_COVER_MAX:
			return true
	return false
