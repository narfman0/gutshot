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

const SANCTUM_CENTER := Vector3(0, 0, -14)  # chunk-local
const SANCTUM_RADIUS := 7.0
const TRESPASS_GRACE_SECS := 6.0

var _trespass_timer := 0.0
var _trespass_warned := false
var _sanctum_label: Label3D

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
		{"skin": "gangster", "pos": Vector3(8.0, 0.1, 14.0), "pack": "salvage", "morale": true},
		# The Assembly: neutral custodians. Not your mission — unless you make
		# them your problem.
		{"skin": "war_robot", "pos": Vector3(-3.0, 0.1, -10.0), "pack": "assembly",
			"faction": Factions.ASSEMBLY, "required": false,
			"gear": "res://resources/gear/machine_laser.tres",
			"patrol": [Vector3(-8.0, 0.1, -8.0), Vector3(8.0, 0.1, -8.0)]},
		{"skin": "robot_f", "pos": Vector3(3.0, 0.1, -10.0), "pack": "assembly",
			"faction": Factions.ASSEMBLY, "required": false,
			"gear": "res://resources/gear/machine_laser.tres",
			"patrol": [Vector3(10.0, 0.1, -2.0), Vector3(-10.0, 0.1, -2.0)]},
		{"skin": "war_robot", "pos": Vector3(0.0, 0.1, -16.0), "pack": "assembly",
			"faction": Factions.ASSEMBLY, "required": false,
			"gear": "res://resources/gear/machine_laser.tres"},
	]

func build_extra_geometry() -> void:
	_build_fabricator()
	add_practical_light(Vector3(0, 2.5, -14), Color(0.4, 1.0, 0.9), 2.2, 9.0)
	add_practical_light(Vector3(-14, 2.2, 2), Color(0.7, 0.9, 1.0), 1.4, 7.0)
	add_practical_light(Vector3(14, 2.2, 0), Color(0.7, 0.9, 1.0), 1.4, 7.0)

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
	if not Engine.is_editor_hint():
		_tick_trespass(delta)

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
