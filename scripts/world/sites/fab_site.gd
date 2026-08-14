@tool
## Fab Level — the Assembly's fabrication floor (docs/locations.md). Machines
## are NEUTRAL — they patrol, they watch, they warn. Shoot one (or overstay
## in the fabricator sanctum) and the faction is in the fight until the crew
## next rests at the hideout (grudges reset on rest, not on travel).
extends SiteChunk

const PROP_SHELF := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Shelf_01.gltf"
const PROP_SHELF_2 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Shelf_02.gltf"
const PROP_EBOX := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Electrical_Box_01.gltf"
const PROP_ROBOT_STATUE := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Robot_Posed_06.gltf"
const CONTAINER_SMALL := "res://assets/meshes/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Prop_Shipping_Container_Small_01.gltf"
const PROP_HOLO_STAND := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Hologram_Stand_01.gltf"
const PROP_HOLO_SIGN := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Holo_Sign_02.gltf"
const PROP_CONSOLE := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Street_Console_01.gltf"
const BLD_PIPE_RING := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Pipe_Large_Circular_01.gltf"
const ENV_HOLO_TREE := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Environment/SM_Env_Hologram_Tree_01.gltf"

const SANCTUM_CENTER := Vector3(0, 0, -14)  # chunk-local
const SANCTUM_RADIUS := 7.0
const TRESPASS_GRACE_SECS := 6.0

## Turf law: gunfire this close to the sanctum is a provocation in itself —
## whoever pulls the trigger. One warning, then a few more shots turn the
## machines on the SHOOTER'S faction. This is the bait play: lure a gang
## pack into machine turf, let them shoot at you, and walk away from the
## three-way fight. The salvage crew on the east line sits well outside the
## ring, so a clean fight over there stays the crew's business.
const TURF_GUARD_RADIUS := 14.0
const TURF_HEAT_PROVOKE := 4.0   # shots (minus decay) that turn the machines
const TURF_HEAT_DECAY := 0.25    # per second — sporadic fire is tolerated

var _trespass_timer := 0.0
var _trespass_warned := false
var _sanctum_label: Label3D
var _turf_heat := {}    # faction -> recent shots fired inside the ring
var _turf_warned := {}  # faction -> warning already given

func _ready() -> void:
	super._ready()  # SiteChunk builds the geometry
	if not Engine.is_editor_hint():
		GameState.shot_fired.connect(_on_shot_fired)

func site_id() -> String:
	return "fab"

func site_name() -> String:
	return "FAB LEVEL"

func arena_half() -> float:
	return 24.0

func ground_color() -> Color:
	return Color(0.30, 0.32, 0.34)  # clean-room composite, brighter than the district

func sun_energy() -> float:
	return 1.1

func fog_density() -> float:
	return 0.004

func ambient() -> String:
	return "ambient_machine"  # maintained, not derelict — the Assembly's hum

func wall_color() -> Color:
	return Color(0.26, 0.28, 0.31)  # clean-room panelling — the ONE kept site

func gates() -> Array:
	return [{"side": "n", "center": -14.0}]  # freight tunnel from Depot 9

## Cold, even, clinical — machine light.
func flood_lights() -> Array:
	return [
		[Vector3(-14, 6, -14), Color(0.7, 0.9, 1.0)],
		[Vector3(14, 6, -14), Color(0.7, 0.9, 1.0)],
		[Vector3(0, 6, 4), Color(0.6, 0.85, 1.0)],
		[Vector3(0, 6, 16), Color(0.5, 0.75, 0.95)],
	]

func cover_layout() -> Array:
	return [
		# Assembly lines: shelf rows east and west.
		[PROP_SHELF, -14.0, -4.0, 90.0], [PROP_SHELF_2, -14.0, 2.0, 90.0],
		[PROP_SHELF, -14.0, 8.0, 90.0],
		[PROP_SHELF_2, 14.0, -4.0, 270.0], [PROP_SHELF, 14.0, 2.0, 270.0],
		[PROP_EBOX, -7.0, 6.0, 0.0], [PROP_EBOX, 7.0, 6.0, 180.0],
		# Salvage mess the bandits made of the east line.
		[CONTAINER_SMALL, 12.0, 12.0, 30.0], [CONTAINER_SMALL, 9.0, 15.0, 75.0],
		# Sanctum dressing: posed frames flanking the fabricator.
		[PROP_ROBOT_STATUE, -4.0, -12.0, 45.0], [PROP_ROBOT_STATUE, 4.0, -12.0, -45.0],
	]

func crew_spawns() -> Array:
	return [
		Vector3(-2.5, 0.1, 19.0), Vector3(0.0, 0.1, 20.0),
		Vector3(2.5, 0.1, 19.0), Vector3(0.0, 0.1, 17.5),
	]

func enemy_spawns() -> Array:
	return [
		# The job: a bandit salvage crew stripping the east assembly line.
		{"skin": "biker", "pos": Vector3(11.0, 0.1, 13.0), "pack": "salvage", "morale": true},
		{"skin": "punk", "pos": Vector3(13.0, 0.1, 10.0), "pack": "salvage", "morale": true},
		{"skin": "gangster", "pos": Vector3(8.0, 0.1, 14.0), "pack": "salvage", "morale": true,
			"gear": "res://resources/gear/enemy_pistol.tres"},
		# The Assembly: neutral custodians. Not your mission — unless you make
		# them your problem.
		{"skin": "war_robot", "pos": Vector3(-3.0, 0.1, -10.0), "pack": "assembly",
			"faction": Factions.ASSEMBLY, "required": false, "pursue": false, "xp": 20,
			"gear": "res://resources/gear/machine_laser.tres",
			"patrol": [Vector3(-8.0, 0.1, -8.0), Vector3(8.0, 0.1, -8.0)]},
		{"skin": "robot_f", "pos": Vector3(3.0, 0.1, -10.0), "pack": "assembly",
			"faction": Factions.ASSEMBLY, "required": false, "pursue": false, "xp": 20,
			"gear": "res://resources/gear/machine_laser.tres",
			"patrol": [Vector3(10.0, 0.1, -2.0), Vector3(-10.0, 0.1, -2.0)]},
		{"skin": "war_robot", "pos": Vector3(0.0, 0.1, -16.0), "pack": "assembly",
			"faction": Factions.ASSEMBLY, "required": false, "pursue": false, "xp": 20,
			"gear": "res://resources/gear/machine_laser.tres"},
	]

func build_extra_geometry() -> void:
	_build_fabricator()
	add_practical_light(Vector3(0, 2.5, -14), Color(0.4, 1.0, 0.9), 2.2, 9.0)
	add_practical_light(Vector3(-14, 2.2, 2), Color(0.7, 0.9, 1.0), 1.4, 7.0)
	add_practical_light(Vector3(14, 2.2, 0), Color(0.7, 0.9, 1.0), 1.4, 7.0)
	# Machine housekeeping: holo fixtures, a status console, plumbing on the
	# west wall — and the Assembly's tended hologram tree by the sanctum.
	add_decor(PROP_HOLO_STAND, Vector3(-10.0, 0, 2.0), 40.0)
	add_decor(PROP_HOLO_SIGN, Vector3(10.0, 0, -3.0), 300.0)
	add_decor(PROP_CONSOLE, Vector3(-17.0, 0, 12.0), 120.0)
	add_decor(BLD_PIPE_RING, Vector3(-23.4, 0, -8.0), 90.0)
	add_decor(ENV_HOLO_TREE, Vector3(-7.5, 0, -17.5), 0.0)
	add_practical_light(Vector3(-7.5, 2.4, -17.5), Color(0.4, 1.0, 0.7), 1.2, 6.0)
	add_neon_sign("FAB LEVEL 3", Vector3(0.0, 2.9, -23.2), Color(0.6, 0.9, 1.0), 0.0, 64)
	add_neon_sign("警告 AUTHORIZED ONLY", Vector3(13.0, 2.3, -23.2),
		Color(1.0, 0.5, 0.3), 0.0, 40)

## The fabricator — the machine the Assembly is protecting. Standing in its
## sanctum ring is trespass: one warning, then the whole floor turns.
func _build_fabricator() -> void:
	var fab := StaticBody3D.new()
	fab.collision_layer = Layers.COVER
	fab.add_to_group("cover")
	fab.add_to_group(NavRuntime.SOURCE_GROUP)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.5, 2.0, 2.5)
	col.shape = box
	col.position.y = 1.0
	fab.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.2, 0.22)
	mat.metallic = 0.7
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.85)
	mat.emission_energy_multiplier = 0.9
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = 1.0
	fab.add_child(mi)
	gen_root().add_child(fab)
	fab.position = SANCTUM_CENTER
	_sanctum_label = Label3D.new()
	_sanctum_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sanctum_label.font_size = 44
	_sanctum_label.pixel_size = 0.004
	_sanctum_label.outline_size = 8
	_sanctum_label.modulate = Color(0.4, 1.0, 0.9)
	_sanctum_label.text = "ASSEMBLY TERRITORY"
	_sanctum_label.position.y = 3.2
	fab.add_child(_sanctum_label)

func _process(delta: float) -> void:
	super._process(delta)  # SiteChunk's flicker tick
	if not Engine.is_editor_hint():
		_tick_trespass(delta)
		_tick_turf_heat(delta)

## Any round fired inside the guard ring heats the shooter's faction toward
## provocation — the machines don't care who you were aiming at.
func _on_shot_fired(shooter: Character) -> void:
	if shooter == null or not is_instance_valid(shooter) \
			or shooter.team == Factions.ASSEMBLY \
			or Factions.hostile(shooter.team, Factions.ASSEMBLY):
		return
	var flat := shooter.global_position - to_global(SANCTUM_CENTER)
	flat.y = 0.0
	if flat.length() > TURF_GUARD_RADIUS:
		return
	var heat: float = _turf_heat.get(shooter.team, 0.0) + 1.0
	_turf_heat[shooter.team] = heat
	if not _turf_warned.get(shooter.team, false):
		_turf_warned[shooter.team] = true
		AudioManager.play_sfx("telegraph")
		if _sanctum_label != null:
			_sanctum_label.text = "CEASE FIRE"
			_sanctum_label.modulate = Color(1.0, 0.5, 0.2)
	if heat >= TURF_HEAT_PROVOKE:
		Factions.provoke(shooter.team, Factions.ASSEMBLY)
		if _sanctum_label != null:
			_sanctum_label.text = "HOSTILE"
			_sanctum_label.modulate = Color(1.0, 0.25, 0.15)

func _tick_turf_heat(delta: float) -> void:
	for faction in _turf_heat:
		var heat: float = maxf(0.0, _turf_heat[faction] - TURF_HEAT_DECAY * delta)
		_turf_heat[faction] = heat
		if heat == 0.0 and _turf_warned.get(faction, false):
			_turf_warned[faction] = false
			if _sanctum_label != null and _sanctum_label.text == "CEASE FIRE":
				_sanctum_label.text = "ASSEMBLY TERRITORY"
				_sanctum_label.modulate = Color(0.4, 1.0, 0.9)

## Trespass: crew inside the sanctum ring get one warning; overstay the grace
## and the Assembly is provoked against the crew.
func _tick_trespass(delta: float) -> void:
	if Factions.hostile(Factions.CREW, Factions.ASSEMBLY):
		return  # already at war — trespass is moot
	var sanctum := to_global(SANCTUM_CENTER)
	var intruding := false
	for c in GameState.living_squad():
		var flat: Vector3 = (c as Node3D).global_position - sanctum
		flat.y = 0.0
		if flat.length() <= SANCTUM_RADIUS:
			intruding = true
			break
	if not intruding:
		_trespass_timer = 0.0
		if _trespass_warned and _sanctum_label != null:
			_sanctum_label.text = "ASSEMBLY TERRITORY"
			_sanctum_label.modulate = Color(0.4, 1.0, 0.9)
			_trespass_warned = false
		return
	_trespass_timer += delta
	if not _trespass_warned:
		_trespass_warned = true
		AudioManager.play_sfx("telegraph")
		if _sanctum_label != null:
			_sanctum_label.text = "LEAVE. NOW."
			_sanctum_label.modulate = Color(1.0, 0.5, 0.2)
	if _trespass_timer >= TRESPASS_GRACE_SECS:
		Factions.provoke(Factions.CREW, Factions.ASSEMBLY)
		if _sanctum_label != null:
			_sanctum_label.text = "HOSTILE"
			_sanctum_label.modulate = Color(1.0, 0.25, 0.15)
