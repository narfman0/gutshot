## Mission root BASE CLASS — docs/architecture.md scene contract:
##   GameWorld → Level (geometry+nav) / Squad / EnemySquad / ObjectiveManager
##             / CameraRig / HUD
## Owns mission lifecycle: builds the arena's cover + navmesh, spawns both
## sides (with a debug fallback squad so the scene runs standalone and in
## headless harnesses), locks the isometric camera to the active character,
## and shows the win/lose overlay.
##
## Levels subclass this (skirmish_level.gd, depot_level.gd) and override the
## data hooks: _arena_half / _ground_color / _cover_layout / _crew_spawns /
## _enemy_spawns / _build_extra_geometry.
class_name GameWorld
extends Node3D

# ── Camera (wayfarer framing, pulled back further for the tactical read) ─────
const _ISO_YAW := deg_to_rad(45.0)
const _ISO_PITCH := deg_to_rad(-30.0)
const _ISO_DIST := 40.0
const _ZOOM_MIN := 11.0
const _ZOOM_MAX := 24.0
const _ZOOM_STEP := 2.0
const _CAM_FOLLOW_SPEED := 8.0
var _zoom := 17.0  # close enough that sprinting reads fast; wheel adjusts

# ── Arena ────────────────────────────────────────────────────────────────────
const _WALL_H := 6.0
const _WALL_T := 1.0

const CharacterScene := preload("res://scenes/characters/character.tscn")

# ── Level data hooks (override per level) ────────────────────────────────────

func _arena_half() -> float:
	return 25.0

func _ground_color() -> Color:
	return Color(0.17, 0.18, 0.21)  # wet asphalt

## Array of [mesh_path, x, z, yaw_deg] — cover props.
func _cover_layout() -> Array:
	return []

func _crew_spawns() -> Array:
	return [
		Vector3(-2.5, 0.1, 20.0), Vector3(0.0, 0.1, 21.0),
		Vector3(2.5, 0.1, 20.0), Vector3(0.0, 0.1, 18.5),
	]

## Array of dicts: {skin, pos: Vector3, pack: String,
##   patrol: Array[Vector3] (optional), morale: bool (optional)}.
func _enemy_spawns() -> Array:
	return []

## Level-specific structures (catwalks, walls, breach doors, transit zones) —
## built after ground/cover, before the navmesh bake.
func _build_extra_geometry() -> void:
	pass

## Shown top-left in the HUD so travel between sites reads instantly.
func _site_name() -> String:
	return "UNKNOWN SITE"

## SceneManager.LEVELS id for this site — the district map marks it.
func _site_id() -> String:
	return ""

## Safe rooms restore the crew on arrival (the hideout's whole job).
func _heals_crew() -> bool:
	return false

func _sun_energy() -> float:
	return 1.5

## Depth fog density (0 = off) — interiors read dustier than the street.
func _fog_density() -> float:
	return 0.0

## Array of [position, color] corner/fill lights — the level's light mood.
func _flood_lights() -> Array:
	return [
		[Vector3(-18, 6, -18), Color(0.2, 0.8, 1.0)],
		[Vector3(18, 6, -18), Color(0.95, 0.3, 0.75)],
		[Vector3(-18, 6, 18), Color(0.95, 0.3, 0.75)],
		[Vector3(18, 6, 18), Color(0.2, 0.8, 1.0)],
	]

@onready var _level: Node3D = $Level
@onready var _squad: Squad = $Squad
@onready var _enemy_squad: Node3D = $EnemySquad
@onready var _objectives: ObjectiveManager = $ObjectiveManager
@onready var _cam_pivot: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D

var _game_over := false

var _nav_rid: RID
var _rebake_queued := false

func _ready() -> void:
	add_to_group("nav_owner")
	Factions.reset_provocations()  # grudges don't cross site loads (yet)
	_setup_environment()
	_setup_ground()
	_setup_cover()
	_build_extra_geometry()
	_setup_bounds()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_nav_rid = NavRuntime.bake(self, Layers.GROUND | Layers.COVER)
	_spawn_crew()
	_spawn_enemies()
	_setup_camera()
	($HUD as Hud).setup(_squad, _objectives, _camera, _site_name())
	_objectives.mission_complete.connect(func(): _show_end_screen(true))
	_objectives.mission_failed.connect(func(): _show_end_screen(false))
	AudioManager.play_ambient()
	if _heals_crew():
		GameState.crew_state = {}  # patched up — wounds don't follow you out
	GameState.save_game(_site_id())  # autosave on arrival (no-op in debug runs)
	SceneManager.fade_in()

## Re-bake the navmesh after geometry changes (a breached door opening a
## path). Deferred + debounced — several doors can break in one explosion.
func rebake_nav() -> void:
	if _rebake_queued:
		return
	_rebake_queued = true
	_do_rebake.call_deferred()

func _do_rebake() -> void:
	# Wait a physics frame so queue_free'd geometry (breached doors) is
	# actually gone before the parser walks the world.
	await get_tree().physics_frame
	_rebake_queued = false
	if _nav_rid.is_valid():
		NavigationServer3D.free_rid(_nav_rid)
	_nav_rid = NavRuntime.bake(self, Layers.GROUND | Layers.COVER)

# ── World building ───────────────────────────────────────────────────────────

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.75)
	env.ambient_light_energy = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1
	# Lighting pass: contact shadows in the corners of low-poly geometry and
	# a filmic curve so the neon doesn't clip to white.
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	if _fog_density() > 0.0:
		env.fog_enabled = true
		env.fog_density = _fog_density()
		env.fog_light_color = Color(0.05, 0.06, 0.08)
		env.fog_sky_affect = 0.0
	($Environment as WorldEnvironment).environment = env
	var sun := $Sun as DirectionalLight3D
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0.0)
	sun.light_color = Color(0.85, 0.88, 1.0)
	sun.light_energy = _sun_energy()
	sun.shadow_enabled = true
	# Fill floods — each level brings its own light mood.
	for corner in _flood_lights():
		var flood := OmniLight3D.new()
		flood.light_color = corner[1]
		flood.light_energy = 2.5
		flood.omni_range = 30.0
		flood.omni_attenuation = 1.2
		flood.shadow_enabled = false
		add_child(flood)
		flood.global_position = corner[0]

func _setup_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = Layers.GROUND
	ground.add_to_group(NavRuntime.SOURCE_GROUP)
	var col := CollisionShape3D.new()
	col.name = "GroundCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(_arena_half() * 2.0, 0.5, _arena_half() * 2.0)
	col.shape = box
	col.position.y = -0.25
	ground.add_child(col)
	var mi := MeshInstance3D.new()
	mi.name = "GroundMesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(_arena_half() * 2.0, _arena_half() * 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _ground_color()
	mat.roughness = 0.4
	mat.metallic = 0.15
	plane.material = mat
	mi.mesh = plane
	ground.add_child(mi)
	_level.add_child(ground)

func _setup_cover() -> void:
	var cover_root := Node3D.new()
	cover_root.name = "Cover"
	_level.add_child(cover_root)
	for entry in _cover_layout():
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
		cover_root.add_child(prop)
		prop.global_position = Vector3(entry[1], 0.0, entry[2])
		prop.rotation.y = deg_to_rad(entry[3])
		_add_aabb_collider(prop, visual)

## Box collider sized from the prop's visual AABB — boxes (not trimesh) so
## CombatBrain's cover-ring extent math has a shape it understands, and so a
## missing mesh (assets not fetched, headless CI) still produces usable cover.
## The mesh AABB must be carried through each MeshInstance3D's transform chain:
## cooked Synty glTFs keep centimetre-scale vertex data corrected by a scaled
## child node, so the raw mesh AABB is ~100× too large.
func _add_aabb_collider(prop: StaticBody3D, visual: Node3D) -> void:
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

func _setup_bounds() -> void:
	var half := _arena_half()
	for side in [
		Vector3(0, 0, -half), Vector3(0, 0, half),
		Vector3(-half, 0, 0), Vector3(half, 0, 0),
	]:
		var wall := StaticBody3D.new()
		wall.collision_layer = Layers.BARRIERS
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var along_x := absf(side.z) > 0.0
		box.size = Vector3(half * 2.0 + _WALL_T * 2.0, _WALL_H, _WALL_T) if along_x \
			else Vector3(_WALL_T, _WALL_H, half * 2.0 + _WALL_T * 2.0)
		col.shape = box
		wall.add_child(col)
		_level.add_child(wall)
		wall.global_position = side + Vector3(0, _WALL_H * 0.5, 0)

# ── Spawning ─────────────────────────────────────────────────────────────────

func _spawn_crew() -> void:
	if GameState.squad.is_empty() and not GameState.run_active:
		GameState.debug_session = true
	var smg: GearItem = load("res://resources/gear/smg.tres")
	var rifle: GearItem = load("res://resources/gear/rifle.tres")
	var pistol: GearItem = load("res://resources/gear/pistol.tres")
	var heal_gun: GearItem = load("res://resources/gear/heal_gun.tres")
	var belt: GearItem = load("res://resources/gear/grenade_belt.tres")
	var crew_keys: Array = Skins.crew_names()
	var members: Array = []
	for i in crew_keys.size():
		var key: String = crew_keys[i]
		var info: Dictionary = Skins.CREW[key]
		var c: Character = CharacterScene.instantiate()
		c.team = 0
		c.display_name = key.capitalize()
		c.anim_set = info["set"]
		c.max_shield = 40.0  # crew get the regenerating layer; enemies don't
		_squad.add_child(c)
		var spawns := _crew_spawns()
		c.global_position = spawns[i % spawns.size()]
		c.setup_skin(info["path"])
		c.equip(rifle if key == "gunner" else smg)
		c.equip(heal_gun if key == "medic" else pistol)
		c.equip(belt)
		# Crew condition carried from the previous site (travel keeps wounds).
		var carried: Dictionary = GameState.crew_state.get(key, {})
		if not carried.is_empty() and not _heals_crew():
			c.hp = clampf(float(carried.get("hp", c.max_hp)), 1.0, c.max_hp)
			c.shield = clampf(float(carried.get("shield", 0.0)), 0.0, c.max_shield)
		_squad.add_member(c)
		_objectives.register(c)
		members.append(c)
	GameState.set_squad(members)
	_squad.set_active(0)

func _spawn_enemies() -> void:
	var smg: GearItem = load("res://resources/gear/enemy_smg.tres")
	var belt: GearItem = load("res://resources/gear/grenade_belt.tres")
	for entry in _enemy_spawns():
		var all_skins := {}
		all_skins.merge(Skins.ENEMIES)
		all_skins.merge(Skins.MACHINES)
		var info: Dictionary = all_skins[entry["skin"]]
		var c: Character = CharacterScene.instantiate()
		c.team = entry.get("faction", Factions.GANGS)
		c.display_name = String(entry["skin"]).capitalize()
		c.anim_set = info["set"]
		c.max_hp = 60.0
		_enemy_squad.add_child(c)
		c.global_position = entry["pos"]
		c.setup_skin(info["path"])
		c.equip(smg)
		c.equip(belt)  # dug-in crew get cover-called too
		var brain := CombatBrain.new()
		brain.name = "CombatBrain"
		c.add_child(brain)
		var controller := EnemyController.new()
		controller.name = "EnemyController"
		controller.pack_id = entry["pack"]
		controller.patrol_points = entry.get("patrol", [])
		controller.has_morale = entry.get("morale", false)
		if entry.has("gear"):
			c.equip(load(entry["gear"]))
			c.select_slot(0)
		c.add_child(controller)
		_objectives.register(c, entry.get("required", true))
		# Enemies get the full send-off; crew corpses stay for the squad read.
		c.character_died.connect(func(body): Juice.death_collapse(body, true))

## Small shadowless practical light — fixtures, signs, machine glow. The
## light-mood floods paint the room; practicals pin light to THINGS.
func add_practical_light(pos: Vector3, color: Color, energy := 1.6, reach := 7.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	_level.add_child(light)
	light.global_position = pos

## A glowing floor pad that travels to another site when the crew's active
## character steps on it — the district's instant-travel connectors.
func add_transit_zone(pos: Vector3, target_level: String, label_text: String) -> void:
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = Layers.SQUAD
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.0, 3.0)
	col.shape = box
	zone.add_child(col)
	var pad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.0, 3.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.9, 1.0, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 1.0)
	mat.emission_energy_multiplier = 1.5
	plane.material = mat
	pad.mesh = plane
	pad.position.y = 0.04
	zone.add_child(pad)
	var sign := Label3D.new()
	sign.text = label_text
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 48
	sign.pixel_size = 0.004
	sign.outline_size = 8
	sign.modulate = Color(0.55, 0.95, 1.0)
	sign.position.y = 1.6
	zone.add_child(sign)
	_level.add_child(zone)
	zone.global_position = pos
	zone.body_entered.connect(func(body: Node3D):
		if body is Character and body == _squad.active_character() and not _game_over:
			SceneManager.change_level(target_level))

# ── Camera ───────────────────────────────────────────────────────────────────

func _setup_camera() -> void:
	_cam_pivot.rotation = Vector3(0.0, _ISO_YAW, 0.0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _zoom
	_camera.rotation = Vector3(_ISO_PITCH, 0.0, 0.0)
	_camera.position = Vector3(0.0, sin(-_ISO_PITCH) * _ISO_DIST, cos(_ISO_PITCH) * _ISO_DIST)
	_camera.near = 0.5
	_camera.far = 200.0
	var active := _squad.active_character()
	if active != null:
		_cam_pivot.global_position = active.global_position

func _process(delta: float) -> void:
	var active := _squad.active_character()
	if active != null and is_instance_valid(active):
		_cam_pivot.global_position = _cam_pivot.global_position.lerp(
			active.global_position, minf(1.0, _CAM_FOLLOW_SPEED * delta))
	_camera.size = lerpf(_camera.size, _zoom, minf(1.0, 10.0 * delta))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(_ZOOM_MIN, _zoom - _ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(_ZOOM_MAX, _zoom + _ZOOM_STEP)
	elif event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	elif event.is_action_pressed("district_map") and not _game_over:
		DistrictMap.toggle(self, _site_id())

# ── Pause ────────────────────────────────────────────────────────────────────

var _pause_layer: CanvasLayer = null

func _toggle_pause() -> void:
	if _game_over:
		return
	if _pause_layer != null:
		_close_pause()
		return
	get_tree().paused = true
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 60
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = UITheme.theme
	panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = _site_name()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.C_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(_close_pause)
	vbox.add_child(resume)
	var restart := Button.new()
	restart.text = "Restart Site"
	restart.pressed.connect(func():
		_close_pause()
		SceneManager.reload_current())
	vbox.add_child(restart)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit)

func _close_pause() -> void:
	if _pause_layer != null:
		_pause_layer.queue_free()
		_pause_layer = null
	get_tree().paused = false

# ── End screen ───────────────────────────────────────────────────────────────

func _show_end_screen(victory: bool) -> void:
	if _game_over:
		return
	_game_over = true
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel := PanelContainer.new()
	panel.theme = UITheme.theme
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "AREA CLEAR" if victory else "SQUAD WIPED"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color",
		UITheme.C_HEAD if victory else UITheme.C_HP_ENEMY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var retry := Button.new()
	retry.text = "Retry"
	retry.pressed.connect(func(): SceneManager.reload_current())
	vbox.add_child(retry)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit)
