## Mission root — docs/architecture.md scene contract:
##   GameWorld → Level (geometry+nav) / Squad / EnemySquad / ObjectiveManager
##             / CameraRig / HUD
## Owns mission lifecycle: builds the arena's cover + navmesh, spawns both
## sides (with a debug fallback squad so the scene runs standalone and in
## headless harnesses), locks the isometric camera to the active character,
## and shows the win/lose overlay.
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
const ARENA_HALF := 25.0  # 50×50 m
const _WALL_H := 6.0
const _WALL_T := 1.0

## Cover prop meshes (full res:// literals so fetch_assets.sh resolves them).
## Crates read as waist/chest-high (half cover); vending machines are
## full-height blockers.
const PROP_CRATE_01 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_01.gltf"
const PROP_CRATE_04 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_04.gltf"
const PROP_CRATE_06 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_06.gltf"
const PROP_VENDING := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Vending_Machine_01.gltf"

## [mesh, x, z, yaw_deg] — hand-placed for lanes and mutual flanks.
const COVER_LAYOUT := [
	[PROP_CRATE_01, -8.0, 8.0, 0.0], [PROP_CRATE_04, -6.5, 8.5, 35.0],
	[PROP_CRATE_06, 7.0, 9.0, 0.0], [PROP_CRATE_01, 9.0, 8.0, 90.0],
	[PROP_VENDING, 0.0, 4.0, 180.0], [PROP_VENDING, 1.4, 4.0, 180.0],
	[PROP_CRATE_04, -12.0, 0.0, 15.0], [PROP_CRATE_01, 12.0, -1.0, 70.0],
	[PROP_CRATE_06, -4.0, -3.0, 0.0], [PROP_CRATE_01, 4.5, -4.0, 20.0],
	[PROP_VENDING, -9.0, -8.0, 90.0], [PROP_CRATE_04, -8.0, -9.5, 0.0],
	[PROP_CRATE_01, 8.5, -10.0, 45.0], [PROP_CRATE_06, 10.0, -8.5, 0.0],
	[PROP_CRATE_04, 0.0, -12.0, 60.0], [PROP_VENDING, 3.0, -15.0, 0.0],
]

const CREW_SPAWNS := [
	Vector3(-2.5, 0.1, 20.0), Vector3(0.0, 0.1, 21.0),
	Vector3(2.5, 0.1, 20.0), Vector3(0.0, 0.1, 18.5),
]

## [skin_key, x, z, pack_id]
const ENEMY_SPAWNS := [
	["punk", -6.0, -6.0, "mid"], ["biker", -3.5, -7.0, "mid"],
	["gangster", 9.0, -12.0, "east"], ["punk_girl", 11.0, -11.0, "east"],
	["punk", -10.0, -12.0, "west"], ["biker", -12.0, -14.0, "west"],
	["gangster", 0.0, -17.0, "west"],
]

const CharacterScene := preload("res://scenes/characters/character.tscn")

@onready var _level: Node3D = $Level
@onready var _squad: Squad = $Squad
@onready var _enemy_squad: Node3D = $EnemySquad
@onready var _objectives: ObjectiveManager = $ObjectiveManager
@onready var _cam_pivot: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D

var _game_over := false

func _ready() -> void:
	_setup_environment()
	_setup_ground()
	_setup_cover()
	_setup_bounds()
	await get_tree().physics_frame
	await get_tree().physics_frame
	NavRuntime.bake(self, Layers.GROUND | Layers.COVER)
	_spawn_crew()
	_spawn_enemies()
	_setup_camera()
	($HUD as Hud).setup(_squad, _objectives, _camera)
	_objectives.mission_complete.connect(func(): _show_end_screen(true))
	_objectives.mission_failed.connect(func(): _show_end_screen(false))
	AudioManager.play_ambient()
	SceneManager.fade_in()

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
	($Environment as WorldEnvironment).environment = env
	var sun := $Sun as DirectionalLight3D
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0.0)
	sun.light_color = Color(0.85, 0.88, 1.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	# Neon corner floods — cyberpunk fill so the arena reads at night.
	for corner in [
		[Vector3(-18, 6, -18), Color(0.2, 0.8, 1.0)],
		[Vector3(18, 6, -18), Color(0.95, 0.3, 0.75)],
		[Vector3(-18, 6, 18), Color(0.95, 0.3, 0.75)],
		[Vector3(18, 6, 18), Color(0.2, 0.8, 1.0)],
	]:
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
	box.size = Vector3(ARENA_HALF * 2.0, 0.5, ARENA_HALF * 2.0)
	col.shape = box
	col.position.y = -0.25
	ground.add_child(col)
	var mi := MeshInstance3D.new()
	mi.name = "GroundMesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA_HALF * 2.0, ARENA_HALF * 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.17, 0.18, 0.21)  # wet asphalt
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
	for entry in COVER_LAYOUT:
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
	for side in [
		Vector3(0, 0, -ARENA_HALF), Vector3(0, 0, ARENA_HALF),
		Vector3(-ARENA_HALF, 0, 0), Vector3(ARENA_HALF, 0, 0),
	]:
		var wall := StaticBody3D.new()
		wall.collision_layer = Layers.BARRIERS
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var along_x := absf(side.z) > 0.0
		box.size = Vector3(ARENA_HALF * 2.0 + _WALL_T * 2.0, _WALL_H, _WALL_T) if along_x \
			else Vector3(_WALL_T, _WALL_H, ARENA_HALF * 2.0 + _WALL_T * 2.0)
		col.shape = box
		wall.add_child(col)
		_level.add_child(wall)
		wall.global_position = side + Vector3(0, _WALL_H * 0.5, 0)

# ── Spawning ─────────────────────────────────────────────────────────────────

func _spawn_crew() -> void:
	if GameState.squad.is_empty():
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
		c.global_position = CREW_SPAWNS[i % CREW_SPAWNS.size()]
		c.setup_skin(info["path"])
		c.equip(rifle if key == "gunner" else smg)
		c.equip(heal_gun if key == "medic" else pistol)
		c.equip(belt)
		_squad.add_member(c)
		_objectives.register(c)
		members.append(c)
	GameState.set_squad(members)
	_squad.set_active(0)

func _spawn_enemies() -> void:
	var smg: GearItem = load("res://resources/gear/enemy_smg.tres")
	var belt: GearItem = load("res://resources/gear/grenade_belt.tres")
	for entry in ENEMY_SPAWNS:
		var info: Dictionary = Skins.ENEMIES[entry[0]]
		var c: Character = CharacterScene.instantiate()
		c.team = 1
		c.display_name = String(entry[0]).capitalize()
		c.anim_set = info["set"]
		c.max_hp = 60.0
		_enemy_squad.add_child(c)
		c.global_position = Vector3(entry[1], 0.1, entry[2])
		c.setup_skin(info["path"])
		c.equip(smg)
		c.equip(belt)  # dug-in crew get cover-called too
		var brain := CombatBrain.new()
		brain.name = "CombatBrain"
		c.add_child(brain)
		var controller := EnemyController.new()
		controller.name = "EnemyController"
		controller.pack_id = entry[3]
		c.add_child(controller)
		_objectives.register(c)
		# Enemies get the full send-off; crew corpses stay for the squad read.
		c.character_died.connect(func(body): Juice.death_collapse(body, true))

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
		get_tree().quit()

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
