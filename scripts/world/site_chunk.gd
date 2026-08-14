@tool
## One site of the Vantag District as a reusable, editor-previewable chunk.
##
## A site scene (scenes/sites/*.tscn) has a SiteChunk subclass as its root and
## builds ALL of its geometry in code, chunk-locally — so the same scene works
## at any district offset, alone in the editor viewport, or instanced into
## scenes/district.tscn alongside every other site. @tool: opening a site
## scene (or the district) shows the built site; generated nodes are never
## given an owner, so nothing generated is ever serialized into the .tscn.
##
## Runtime-only concerns (crew/enemy spawning, navmesh, site regions, saves,
## audio) live in GameWorld — a chunk is geometry plus data hooks.
class_name SiteChunk
extends Node3D

const WALL_H := 6.0
const WALL_T := 1.0
const GATE_WIDTH := 6.0

## Set by GameWorld at runtime; null in the editor and in bare scenes.
var world: GameWorld = null

var _gen: Node3D = null

# ── Data hooks (override per site) ───────────────────────────────────────────

func site_id() -> String:
	return ""

func site_name() -> String:
	return "UNKNOWN SITE"

func arena_half() -> float:
	return 25.0

func ground_color() -> Color:
	return Color(0.17, 0.18, 0.21)  # wet asphalt

## Array of [mesh_path, x, z, yaw_deg, (floor_y)] — cover props, chunk-local.
func cover_layout() -> Array:
	return []

## Chunk-local crew anchors — where the squad stands when arriving here.
func crew_spawns() -> Array:
	return [
		Vector3(-2.5, 0.1, 20.0), Vector3(0.0, 0.1, 21.0),
		Vector3(2.5, 0.1, 20.0), Vector3(0.0, 0.1, 18.5),
	]

## Array of dicts: {skin, pos: Vector3 (chunk-local), pack: String,
##   patrol: Array[Vector3] (chunk-local), morale, faction, required, gear,
##   aggro} — spawned (and respawned) by GameWorld.
func enemy_spawns() -> Array:
	return []

## Site-specific structures — built after ground/cover, before bounds.
func build_extra_geometry() -> void:
	pass

## Safe rooms rest the crew on entry (the hideout's whole job).
func heals_crew() -> bool:
	return false

## Walk heights of each floor, ground first; >1 entry gets a FloorSystem.
func floor_heights() -> Array:
	return [0.0]

# Per-site light/air mood — GameWorld lerps the global env toward the
# active site's values.
func sun_energy() -> float:
	return 1.5

## Looping ambient bed for this site (assets/audio/<name>.wav) — crossfaded
## on entry; corridors keep the last site's bed, like the HUD label.
func ambient() -> String:
	return "ambient_city"

func fog_density() -> float:
	return 0.0

## Array of [local_pos, color] fill lights — the site's light mood.
func flood_lights() -> Array:
	return []

## Wall openings: [{side: "n"|"s"|"e"|"w", center: float (coord along the
## wall), width: float (optional)}]. n = -z, s = +z, w = -x, e = +x.
## GameWorld runs connector corridors between paired gates.
func gates() -> Array:
	return []

## Visible perimeter-wall tone — rooms read as rooms, in the site's palette.
func wall_color() -> Color:
	return Color(0.20, 0.20, 0.22)

## Pavement seams + stains on the ground plane (off for special floors).
func ground_detail() -> bool:
	return true

## Ground surface roughness — 0.4 reads as worn concrete; the tower lobby
## drops it for the polished-marble sheen.
func ground_roughness() -> float:
	return 0.4

# ── Build ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	build_geometry()

## Idempotent: everything generated lives under one unowned child, replaced
## wholesale on rebuild (this is what keeps @tool preview safe to re-run).
func build_geometry() -> void:
	if _gen != null and is_instance_valid(_gen):
		_gen.free()
	var stale := get_node_or_null("Generated")
	if stale != null:
		stale.free()
	_gen = Node3D.new()
	_gen.name = "Generated"
	add_child(_gen)
	_setup_ground()
	_setup_cover()
	_setup_floods()
	build_extra_geometry()
	_setup_bounds()

## World-space XZ footprint — GameWorld uses this for site regions and
## FloorSystem scoping. Assumes chunks are translated, never rotated.
func bounds_rect() -> Rect2:
	var half := arena_half()
	return Rect2(global_position.x - half, global_position.z - half,
		half * 2.0, half * 2.0)

## World-space info for gate `index`: midpoint on the wall, outward normal,
## width — GameWorld builds connector corridors from paired gate infos.
func gate_info(index: int) -> Dictionary:
	var gate: Dictionary = gates()[index]
	var half := arena_half()
	var c: float = gate["center"]
	var local := Vector3.ZERO
	var dir := Vector3.ZERO
	match gate["side"]:
		"n":
			local = Vector3(c, 0, -half)
			dir = Vector3(0, 0, -1)
		"s":
			local = Vector3(c, 0, half)
			dir = Vector3(0, 0, 1)
		"w":
			local = Vector3(-half, 0, c)
			dir = Vector3(-1, 0, 0)
		"e":
			local = Vector3(half, 0, c)
			dir = Vector3(1, 0, 0)
	return {"pos": to_global(local), "dir": dir,
		"width": gate.get("width", GATE_WIDTH)}

func _setup_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = Layers.GROUND
	ground.add_to_group(NavRuntime.SOURCE_GROUP)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(arena_half() * 2.0, 0.5, arena_half() * 2.0)
	col.shape = box
	col.position.y = -0.25
	ground.add_child(col)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(arena_half() * 2.0, arena_half() * 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ground_color()
	mat.roughness = ground_roughness()
	mat.metallic = 0.15
	plane.material = mat
	mi.mesh = plane
	ground.add_child(mi)
	_gen.add_child(ground)
	if ground_detail():
		_ground_seams()
		_ground_stains()

## Pavement seam grid — thin darker strips break the single-color plane.
func _ground_seams() -> void:
	var half := arena_half()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ground_color().darkened(0.4)
	mat.roughness = 0.7
	var step := 6.0
	var i := 1
	while i * step < half * 2.0 - 1.0:
		var offset := -half + i * step
		for axis in 2:
			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(half * 2.0, 0.02, 0.12) if axis == 0 \
				else Vector3(0.12, 0.02, half * 2.0)
			mesh.material = mat
			mi.mesh = mesh
			_gen.add_child(mi)
			mi.position = Vector3(0, 0.012, offset) if axis == 0 \
				else Vector3(offset, 0.012, 0)
		i += 1

## Grime patches — deterministic per site, so the editor preview is stable.
func _ground_stains() -> void:
	var half := arena_half()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ground_color().darkened(0.22)
	mat.roughness = 0.9
	var count := int(half / 3.0)
	for i in count:
		var h := hash(site_id() + str(i))
		var x := float(h % 1000) / 1000.0 * (half * 2.0 - 6.0) - half + 3.0
		var z := float((h / 1000) % 1000) / 1000.0 * (half * 2.0 - 6.0) - half + 3.0
		var size := 1.2 + float(h % 7) * 0.25
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(size, size * (0.6 + float(h % 5) * 0.15))
		plane.material = mat
		mi.mesh = plane
		_gen.add_child(mi)
		mi.position = Vector3(x, 0.008, z)
		mi.rotation.y = deg_to_rad(float(h % 360))

func _setup_cover() -> void:
	for entry in cover_layout():
		var scene = load(entry[0])
		var prop := StaticBody3D.new()
		prop.collision_layer = Layers.COVER
		prop.add_to_group("cover")
		prop.add_to_group(NavRuntime.SOURCE_GROUP)
		var visual: Node3D = null
		if scene != null:
			visual = scene.instantiate()
			visual.scale.y = Character.VERTICAL_SQUASH  # squat world, squat props
			prop.add_child(visual)
		_gen.add_child(prop)
		# Optional 5th element: floor height — cover on upper decks.
		prop.position = Vector3(entry[1], entry[4] if entry.size() > 4 else 0.0, entry[2])
		prop.rotation.y = deg_to_rad(entry[3])
		add_aabb_collider(prop, visual)

## Box collider sized from the prop's visual AABB — boxes (not trimesh) so
## CombatBrain's cover-ring extent math has a shape it understands, and so a
## missing mesh (assets not fetched, headless CI) still produces usable cover.
## Static — GameWorld's corridor dressing builds props the same way.
static func add_aabb_collider(prop: StaticBody3D, visual: Node3D) -> void:
	var aabb := AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 1.2, 1.2))
	if visual != null:
		var inv := prop.global_transform.affine_inverse()
		var found := false
		for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var mesh_aabb: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
			aabb = mesh_aabb if not found else aabb.merge(mesh_aabb)
			found = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size
	col.shape = box
	col.position = aabb.get_center()
	prop.add_child(col)

## Fill floods — each site brings its own light mood into the shared world.
func _setup_floods() -> void:
	for entry in flood_lights():
		var flood := OmniLight3D.new()
		flood.light_color = entry[1]
		flood.light_energy = 2.5
		flood.omni_range = 30.0
		flood.omni_attenuation = 1.2
		flood.shadow_enabled = false
		_gen.add_child(flood)
		flood.position = entry[0]

## Invisible boundary walls with gaps at the gates — connectors dock there.
func _setup_bounds() -> void:
	var half := arena_half()
	for side in ["n", "s", "w", "e"]:
		var gaps: Array = []
		for gate in gates():
			if gate["side"] == side:
				var w: float = gate.get("width", GATE_WIDTH)
				gaps.append([gate["center"] - w * 0.5, gate["center"] + w * 0.5])
		gaps.sort_custom(func(a, b): return a[0] < b[0])
		var cursor := -half - WALL_T
		for gap in gaps:
			if gap[0] > cursor:
				_bounds_wall(side, cursor, gap[0])
			cursor = gap[1]
		if cursor < half + WALL_T:
			_bounds_wall(side, cursor, half + WALL_T)

func _bounds_wall(side: String, from: float, to: float) -> void:
	var half := arena_half()
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.BARRIERS
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var mid := (from + to) * 0.5
	var length := to - from
	match side:
		"n", "s":
			box.size = Vector3(length, WALL_H, WALL_T)
			wall.position = Vector3(mid, WALL_H * 0.5, -half if side == "n" else half)
		"w", "e":
			box.size = Vector3(WALL_T, WALL_H, length)
			wall.position = Vector3(-half if side == "w" else half, WALL_H * 0.5, mid)
	col.shape = box
	wall.add_child(col)
	_gen.add_child(wall)
	# Visible face: TALL on the camera-far sides (n, w), a knee curb on the
	# near sides — the same iso trick as the corridors, so sites read as
	# rooms without ever blinding the camera.
	var tall := side == "n" or side == "w"
	var face_h := 3.2 if tall else 0.9
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, face_h, 0.5) if side == "n" or side == "s" \
		else Vector3(0.5, face_h, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = wall_color()
	mat.roughness = 0.85
	mesh.material = mat
	mi.mesh = mesh
	wall.add_child(mi)
	mi.position = Vector3(0, face_h * 0.5 - WALL_H * 0.5, 0)

# ── Site-geometry helpers (chunk-local positions) ────────────────────────────

## Small shadowless practical light — fixtures, signs, machine glow.
## `flicker`: dying-neon jitter (registered with the chunk's flicker tick).
func add_practical_light(pos: Vector3, color: Color, energy := 1.6, reach := 7.0,
		flicker := false) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	_gen.add_child(light)
	light.position = pos
	if flicker:
		_flickers.append({"node": light, "base": energy,
			"phase": float(_flickers.size()) * 1.73})

## Visual-only dressing prop — no collider, no cover, no navmesh carve.
## For streetlights, signs, wires, junk: things bullets and bodies ignore.
func add_decor(mesh_path: String, pos: Vector3, yaw := 0.0, extra_scale := 1.0) -> void:
	var scene = load(mesh_path)
	if scene == null:
		return
	var visual: Node3D = scene.instantiate()
	var s := extra_scale * cm_correction(visual)
	visual.scale = Vector3(s, s * Character.VERTICAL_SQUASH, s)
	_gen.add_child(visual)
	visual.position = pos
	visual.rotation.y = deg_to_rad(yaw)

## Some cooked glTFs (the Buildings tree) ship RAW centimetre vertices with
## no corrective child — a "tower" measures 1.5 km. Measure through the FULL
## transform chain (correctives included) and shrink only the truly raw.
## Nothing we dress with is legitimately longer than a truck (~15 m); raw-cm
## meshes measure 100×, so 25 m splits the populations cleanly.
static func cm_correction(visual: Node3D) -> float:
	var aabb := AABB()
	var found := false
	for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var a: AABB = _transform_to(mi, visual) * mi.mesh.get_aabb()
		aabb = a if not found else aabb.merge(a)
		found = true
	if found and aabb.get_longest_axis_size() > 25.0:
		return 0.01
	return 1.0

static func _transform_to(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D()
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

## Wall-mounted neon lettering — the district's voice. Glow env makes hot
## colors bloom; `flicker` gives it the dying-tube stutter.
func add_neon_sign(text: String, pos: Vector3, color: Color, yaw := 0.0,
		font_size := 64, flicker := false) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = font_size
	sign.pixel_size = 0.012
	sign.outline_size = 10
	sign.modulate = color
	_gen.add_child(sign)
	sign.position = pos
	sign.rotation.y = deg_to_rad(yaw)
	if flicker:
		_flickers.append({"node": sign, "base": 1.0,
			"phase": float(_flickers.size()) * 2.31})

## A slow steam column — vents, grates, cooling stacks. Idle life.
func add_steam(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 2.8
	p.preprocess = 2.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.72, 0.76, 0.13)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	p.mesh = quad
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = Vector3(0.15, 0.5, 0.1)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.7
	_gen.add_child(p)
	p.position = pos + Vector3(0, 0.2, 0)

var _flickers: Array = []

## Dying-neon tick: registered lights stutter, registered signs dim with
## them. Deterministic waveform — no randf, so headless runs are stable.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _flickers.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0
	for f in _flickers:
		var node = f["node"]
		if not is_instance_valid(node):
			continue
		var wave := sin(t * 11.0 + f["phase"]) * sin(t * 5.7 + f["phase"] * 2.3)
		var on := 0.62 + 0.38 * clampf(wave * 2.5 + 0.5, 0.0, 1.0)
		if node is Light3D:
			(node as Light3D).light_energy = f["base"] * on
		elif node is Label3D:
			(node as Label3D).modulate.a = 0.45 + 0.55 * on

## Walkable slab or ramp (decks, stairs): GROUND so it takes movement, the
## cursor ray, and the navmesh bake; COVER so elevation LOS is real — a deck
## slab blocks sight and shots through the floor.
func add_walkable_box(pos: Vector3, size: Vector3, tilt_x_deg := 0.0, tilt_z_deg := 0.0,
		color := Color(0.25, 0.28, 0.30), glow := 0.15) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.GROUND | Layers.COVER
	body.add_to_group(NavRuntime.SOURCE_GROUP)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	mat.metallic = 0.5
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = glow
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	_gen.add_child(body)
	body.position = pos
	body.rotation.x = deg_to_rad(tilt_x_deg)
	body.rotation.z = deg_to_rad(tilt_z_deg)

## Railing: visual only (no collider) — shots pass, and dropping off a deck
## stays a legal shortcut down. Default is the district's hazard-yellow
## glow; the tower's balustrade passes marble and barely any.
func add_rail(pos: Vector3, size: Vector3,
		color := Color(0.7, 0.6, 0.15), glow := 0.4) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color.lightened(0.25)
	mat.emission_energy_multiplier = glow
	mesh.material = mat
	mi.mesh = mesh
	_gen.add_child(mi)
	mi.position = pos

## Generated-content root — site subclasses parent custom structures here.
func gen_root() -> Node3D:
	return _gen
