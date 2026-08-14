@tool
## Vantag Tower (docs/locations.md: public floors, corporate security
## posture; going loud here burns the district). Styled on THE lobby scene,
## now in the film's palette: DARK polished granite, pale columns lit by
## their own pools, dim even fill — contrast, not wash.
##
## Three levels, stairs all the way (the elevators are dressing — sealed):
##   ground  — the public lobby: column grid, security desk, detector arch
##   4 m     — the mezzanine balcony ringing the room
##   8 m     — the RESTRICTED executive floor, and the sealed door to
##             whatever Level 4 is becoming (the campaign's problem)
##
## Vantag Security (Factions.CORP) holds all three: neutral to the crew —
## the lobby is public until you start something. Two ways to start it:
## gunfire in the lobby (one warning), or climbing past the rope (grace,
## then the floor turns). They're the mirror squad: shields, bounding
## overwatch, a shield-mender walking the exec floor, no morale, no mercy.
extends SiteChunk

const MEZZ_H := 4.0
const EXEC_H := 8.0
const DECK_T := 0.35
const STAIR_TILT := 26.57

const MARBLE := Color(0.50, 0.50, 0.47)      # column stone, pool-lit
const GRANITE_MID := Color(0.30, 0.30, 0.29) # deck stone
const GRANITE := Color(0.13, 0.14, 0.15)     # the dark polished floor

const TRESPASS_GRACE_SECS := 4.0
const GUNFIRE_PROVOKE_SHOTS := 1.5  # i.e. a second shot soon after the first
const GUNFIRE_DECAY := 0.1

var _status_label: Label3D
var _trespass_timer := 0.0
var _trespass_warned := false
var _fire_heat := {}    # faction -> recent shots inside the lobby
var _fire_warned := {}

func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		GameState.shot_fired.connect(_on_shot_fired)

func site_id() -> String:
	return "tower"

func site_name() -> String:
	return "VANTAG TOWER — LOBBY"

func arena_half() -> float:
	return 26.0

func ground_color() -> Color:
	return GRANITE

func ground_roughness() -> float:
	return 0.08  # mirror-polished — the pools smear across it

func sun_energy() -> float:
	return 0.55  # dim fill; the uplights carry the room

func fog_density() -> float:
	return 0.0015

func ambient() -> String:
	return "ambient_lobby"

func wall_color() -> Color:
	return Color(0.24, 0.25, 0.26)

func floor_heights() -> Array:
	return [0.0, MEZZ_H, EXEC_H]

func gates() -> Array:
	return [{"side": "s", "center": -6.0}]  # the plaza from the street

## Dim, cool, even — the pools do the talking.
func flood_lights() -> Array:
	return [
		[Vector3(-16, 7, -16), Color(0.8, 0.87, 1.0), 1.2],
		[Vector3(16, 7, -16), Color(0.8, 0.87, 1.0), 1.2],
		[Vector3(0, 8, 0), Color(0.85, 0.9, 1.0), 1.3],
		[Vector3(0, 7, 16), Color(0.8, 0.87, 1.0), 1.2],
	]

func crew_spawns() -> Array:
	return [
		Vector3(-7.5, 0.1, 22.5), Vector3(-5.0, 0.1, 23.5),
		Vector3(-2.5, 0.1, 22.5), Vector3(-5.0, 0.1, 21.0),
	]

func enemy_spawns() -> Array:
	return [
		# The desk detail — patrols the aisle, neutral until you're not.
		{"skin": "suit", "pos": Vector3(-2.0, 0.1, 13.0), "pack": "lobby",
			"faction": Factions.CORP, "required": false, "disciplined": true,
			"shield": 30.0, "xp": 20, "aggro": 13.0, "pursue": false,
			"patrol": [Vector3(-6.0, 0.1, 8.0), Vector3(6.0, 0.1, 8.0)]},
		{"skin": "suit", "pos": Vector3(3.0, 0.1, 14.0), "pack": "lobby",
			"faction": Factions.CORP, "required": false, "disciplined": true,
			"shield": 30.0, "xp": 20, "aggro": 13.0, "pursue": false},
		# The balcony watch — the rail owns the floor below.
		{"skin": "suit", "pos": Vector3(-22.0, 4.15, 0.0), "pack": "balcony",
			"faction": Factions.CORP, "required": false, "disciplined": true,
			"shield": 30.0, "xp": 20, "aggro": 16.0, "pursue": false,
			"patrol": [Vector3(-22.0, MEZZ_H, 10.0), Vector3(-22.0, MEZZ_H, -14.0)]},
		{"skin": "suit", "pos": Vector3(22.0, 4.15, -4.0), "pack": "balcony",
			"faction": Factions.CORP, "required": false, "disciplined": true,
			"shield": 30.0, "xp": 20, "aggro": 16.0, "pursue": false,
			"patrol": [Vector3(22.0, MEZZ_H, 10.0), Vector3(22.0, MEZZ_H, -14.0)]},
		{"skin": "suit", "pos": Vector3(0.0, 4.15, -21.0), "pack": "balcony",
			"faction": Factions.CORP, "required": false, "disciplined": true,
			"shield": 30.0, "xp": 20, "aggro": 16.0, "pursue": false,
			"patrol": [Vector3(-14.0, MEZZ_H, -22.0), Vector3(14.0, MEZZ_H, -22.0)]},
		# The executive floor: the mirror squad — three guns in bounding
		# overwatch and a mender keeping their shields topped.
		{"skin": "suit", "pos": Vector3(-10.0, 8.15, -18.0), "pack": "exec",
			"faction": Factions.CORP, "required": false, "disciplined": true,
			"shield": 40.0, "xp": 25, "aggro": 14.0, "pursue": false,
			"patrol": [Vector3(-14.0, EXEC_H, -14.0), Vector3(-6.0, EXEC_H, -22.0)]},
		{"skin": "suit", "pos": Vector3(-2.0, 8.15, -22.0), "pack": "exec",
			"faction": Factions.CORP, "required": false, "disciplined": true,
			"shield": 40.0, "xp": 25, "aggro": 14.0, "pursue": false},
		{"skin": "suit", "pos": Vector3(5.0, 8.15, -16.0), "pack": "exec",
			"faction": Factions.CORP, "required": false, "disciplined": true,
			"shield": 40.0, "xp": 25, "aggro": 14.0, "pursue": false,
			"patrol": [Vector3(9.0, EXEC_H, -14.0), Vector3(0.0, EXEC_H, -13.0)]},
		{"skin": "suit", "pos": Vector3(0.0, 8.15, -19.0), "pack": "exec",
			"faction": Factions.CORP, "required": false,
			"shield": 40.0, "xp": 25, "aggro": 14.0, "pursue": false,
			"gear": "res://resources/gear/corp_mender.tres"},
	]

func build_extra_geometry() -> void:
	_build_columns()
	_build_desk_and_door()
	_build_mezzanine()
	_build_exec_floor()
	_build_elevators()
	add_neon_sign("VANTAG", Vector3(0.0, 5.9, -25.2), Color(0.88, 0.95, 1.0), 0.0, 110)

## Two ranks of marble columns flanking the central aisle — each lit by its
## own uplight pool against the dark granite. Real chewable cover.
func _build_columns() -> void:
	for x in [-6.0, 6.0]:
		for z in [-16.0, -9.0, -2.0, 5.0, 12.0]:
			_stone_box(Vector3(x, 0, z), Vector3(1.7, 4.6, 1.7), MARBLE, true)
			add_practical_light(Vector3(x, 3.9, z), Color(0.9, 0.94, 1.0), 1.4, 5.5)

func _build_desk_and_door() -> void:
	_stone_box(Vector3(0.5, 0, 16.5), Vector3(6.0, 1.1, 1.5), GRANITE_MID, true)
	add_practical_light(Vector3(0.5, 1.6, 16.5), Color(0.8, 0.9, 1.0), 1.2, 5.0)
	for px in [-7.4, -4.6]:
		_stone_box(Vector3(px, 0, 20.5), Vector3(0.22, 2.3, 0.5), GRANITE_MID, false)
	var lintel := _stone_box(Vector3(-6.0, 0, 20.5), Vector3(3.0, 0.2, 0.5), GRANITE_MID, false)
	lintel.position.y = 2.3
	# The house rules, posted over the desk.
	_status_label = Label3D.new()
	_status_label.text = "VANTAG SECURITY — WEAPONS DOWN"
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.font_size = 40
	_status_label.pixel_size = 0.004
	_status_label.outline_size = 8
	_status_label.modulate = Color(0.7, 0.85, 1.0)
	gen_root().add_child(_status_label)
	_status_label.position = Vector3(0.5, 3.0, 16.5)

func _build_mezzanine() -> void:
	var deck_y := MEZZ_H - DECK_T * 0.5
	add_walkable_box(Vector3(0.0, deck_y, -22.0), Vector3(52.0, DECK_T, 8.0),
		0.0, 0.0, GRANITE_MID, 0.02)   # north
	add_walkable_box(Vector3(-22.0, deck_y, -2.0), Vector3(8.0, DECK_T, 32.0),
		0.0, 0.0, GRANITE_MID, 0.02)   # west
	add_walkable_box(Vector3(22.0, deck_y, -2.0), Vector3(8.0, DECK_T, 32.0),
		0.0, 0.0, GRANITE_MID, 0.02)   # east
	add_rail(Vector3(0.0, MEZZ_H + 0.45, -18.0), Vector3(36.0, 0.9, 0.1),
		Color(0.58, 0.58, 0.55), 0.04)
	add_rail(Vector3(-18.0, MEZZ_H + 0.45, -2.0), Vector3(0.1, 0.9, 32.0),
		Color(0.58, 0.58, 0.55), 0.04)
	add_rail(Vector3(18.0, MEZZ_H + 0.45, -2.0), Vector3(0.1, 0.9, 32.0),
		Color(0.58, 0.58, 0.55), 0.04)
	# Staircases: floor at z≈22.6 rising north to the deck edge at z≈14.
	add_walkable_box(Vector3(-22.0, MEZZ_H * 0.5 - 0.175, 18.2),
		Vector3(4.0, DECK_T, 8.94), STAIR_TILT, 0.0, GRANITE_MID, 0.02)
	add_walkable_box(Vector3(22.0, MEZZ_H * 0.5 - 0.175, 18.2),
		Vector3(4.0, DECK_T, 8.94), STAIR_TILT, 0.0, GRANITE_MID, 0.02)

## The restricted floor over the north balcony — stairs from the north deck
## rise to it (no elevator; you EARN the view). Exec desks, the mender's
## beat, and the sealed slab where Level 4 begins.
func _build_exec_floor() -> void:
	add_walkable_box(Vector3(-2.5, EXEC_H - DECK_T * 0.5, -18.0),
		Vector3(31.0, DECK_T, 14.0), 0.0, 0.0, GRANITE_MID, 0.02)
	# Stair on the north deck: deck at x≈21.7 rising west to the slab at x≈12.7.
	add_walkable_box(Vector3(17.2, (MEZZ_H + EXEC_H) * 0.5 - 0.175, -21.5),
		Vector3(8.94, DECK_T, 4.0), 0.0, -STAIR_TILT, GRANITE_MID, 0.02)
	# Balustrade — gap on the east edge where the stair lands.
	add_rail(Vector3(-2.5, EXEC_H + 0.45, -11.0), Vector3(31.0, 0.9, 0.1),
		Color(0.58, 0.58, 0.55), 0.04)
	add_rail(Vector3(-18.0, EXEC_H + 0.45, -18.0), Vector3(0.1, 0.9, 14.0),
		Color(0.58, 0.58, 0.55), 0.04)
	add_rail(Vector3(13.0, EXEC_H + 0.45, -24.2), Vector3(0.1, 0.9, 1.6),
		Color(0.58, 0.58, 0.55), 0.04)
	add_rail(Vector3(13.0, EXEC_H + 0.45, -15.2), Vector3(0.1, 0.9, 8.4),
		Color(0.58, 0.58, 0.55), 0.04)
	# Exec furniture + light pools.
	var desk_a := _stone_box(Vector3(-10.0, 0, -20.0), Vector3(4.0, 0.9, 1.6), GRANITE_MID, true)
	desk_a.position.y = EXEC_H
	var desk_b := _stone_box(Vector3(4.0, 0, -14.5), Vector3(4.0, 0.9, 1.6), GRANITE_MID, true)
	desk_b.position.y = EXEC_H
	add_practical_light(Vector3(-10, EXEC_H + 3.0, -18), Color(0.85, 0.9, 1.0), 1.3, 6.0)
	add_practical_light(Vector3(6, EXEC_H + 3.0, -16), Color(0.85, 0.9, 1.0), 1.3, 6.0)
	# The sealed way up — Level 4 is the campaign's problem.
	var seal := _stone_box(Vector3(-2.5, 0, -24.6), Vector3(3.0, 2.6, 0.4),
		Color(0.16, 0.17, 0.19), true)
	seal.position.y = EXEC_H
	add_neon_sign("LEVEL 4 — SEALED", Vector3(-2.5, EXEC_H + 3.1, -24.2),
		Color(1.0, 0.35, 0.3), 0.0, 40)
	add_practical_light(Vector3(-2.5, EXEC_H + 2.4, -23.6), Color(1.0, 0.3, 0.25), 1.0, 4.0)

## The elevator bank under the north balcony — pure dressing now; the
## stairs are the way up.
func _build_elevators() -> void:
	for x in [-6.0, 0.0, 6.0]:
		var door := _stone_box(Vector3(x, 0, -25.3), Vector3(2.2, 2.7, 0.35),
			Color(0.28, 0.30, 0.32), false)
		var mi := door.get_child(0) as MeshInstance3D
		var mat := (mi.mesh as BoxMesh).material as StandardMaterial3D
		mat.metallic = 0.8
		mat.roughness = 0.25
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.8, 1.0)
		mat.emission_energy_multiplier = 0.08
		add_practical_light(Vector3(x, 2.6, -24.4), Color(0.6, 0.85, 1.0), 0.8, 4.0)

## A stone slab: mesh always; collider + cover group when `solid`.
func _stone_box(pos: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.COVER
		body.add_to_group("cover")
		body.add_to_group(NavRuntime.SOURCE_GROUP)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		col.shape = box
		col.position.y = size.y * 0.5
		body.add_child(col)
		root = body
	else:
		root = Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.18
	mat.metallic = 0.05
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = size.y * 0.5
	root.add_child(mi)
	gen_root().add_child(root)
	root.position = pos
	return root

# ── House rules: gunfire and the rope ────────────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)  # SiteChunk's flicker tick
	if not Engine.is_editor_hint():
		_tick_trespass(delta)
		_tick_fire_heat(delta)

## Climbing past the lobby while neutral is trespass: one warning, a short
## grace, then the whole detail turns.
func _tick_trespass(delta: float) -> void:
	if Factions.hostile(Factions.CREW, Factions.CORP):
		return
	var intruding := false
	for c in GameState.living_squad():
		var pos: Vector3 = (c as Node3D).global_position
		if pos.y > 2.5 and bounds_rect().has_point(Vector2(pos.x, pos.z)):
			intruding = true
			break
	if not intruding:
		_trespass_timer = 0.0
		if _trespass_warned and _status_label != null:
			_status_label.text = "VANTAG SECURITY — WEAPONS DOWN"
			_status_label.modulate = Color(0.7, 0.85, 1.0)
			_trespass_warned = false
		return
	_trespass_timer += delta
	if not _trespass_warned:
		_trespass_warned = true
		AudioManager.play_sfx("telegraph")
		if _status_label != null:
			_status_label.text = "RESTRICTED LEVEL — TURN AROUND"
			_status_label.modulate = Color(1.0, 0.6, 0.25)
	if _trespass_timer >= TRESPASS_GRACE_SECS:
		Factions.provoke(Factions.CREW, Factions.CORP)
		if _status_label != null:
			_status_label.text = "SECURITY RESPONSE"
			_status_label.modulate = Color(1.0, 0.3, 0.25)

## Gunfire anywhere in the tower: first shot draws the warning, the second
## turns the detail on the shooter's faction. Steel stays silent.
func _on_shot_fired(shooter: Character) -> void:
	if shooter == null or not is_instance_valid(shooter) \
			or shooter.team == Factions.CORP \
			or Factions.hostile(shooter.team, Factions.CORP):
		return
	if not bounds_rect().has_point(
			Vector2(shooter.global_position.x, shooter.global_position.z)):
		return
	var heat: float = _fire_heat.get(shooter.team, 0.0) + 1.0
	_fire_heat[shooter.team] = heat
	if not _fire_warned.get(shooter.team, false):
		_fire_warned[shooter.team] = true
		AudioManager.play_sfx("telegraph")
		if _status_label != null:
			_status_label.text = "SHOTS FIRED — STAND DOWN"
			_status_label.modulate = Color(1.0, 0.6, 0.25)
	if heat >= GUNFIRE_PROVOKE_SHOTS:
		Factions.provoke(shooter.team, Factions.CORP)
		if _status_label != null:
			_status_label.text = "SECURITY RESPONSE"
			_status_label.modulate = Color(1.0, 0.3, 0.25)

func _tick_fire_heat(delta: float) -> void:
	for faction in _fire_heat:
		var heat: float = maxf(0.0, _fire_heat[faction] - GUNFIRE_DECAY * delta)
		_fire_heat[faction] = heat
		if heat == 0.0 and _fire_warned.get(faction, false):
			_fire_warned[faction] = false
			if _status_label != null and _status_label.text == "SHOTS FIRED — STAND DOWN":
				_status_label.text = "VANTAG SECURITY — WEAPONS DOWN"
				_status_label.modulate = Color(0.7, 0.85, 1.0)