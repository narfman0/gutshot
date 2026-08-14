## The Hideout — the crew's bolt-hole in the district margins, the one safe
## place (docs/narrative.md). No enemies, no objectives: mission select via
## the district-map console (or M anywhere), loadout features later.
extends GameWorld

const PROP_SHELF := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Shelf_01.gltf"
const PROP_SHELF_WALL := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Shelf_Wall_01.gltf"
const PROP_VENDING := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Vending_Machine_01.gltf"
const PROP_CRATE := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_06.gltf"

func _arena_half() -> float:
	return 12.0

func _ground_color() -> Color:
	return Color(0.16, 0.14, 0.12)  # scuffed deck plating, almost warm

func _site_name() -> String:
	return "THE HIDEOUT"

func _site_id() -> String:
	return "hideout"

func _heals_crew() -> bool:
	return true  # the safe room patches everyone up

func _sun_energy() -> float:
	return 0.5

func _fog_density() -> float:
	return 0.01  # close, smoky, safe

## Warm low light — the one place in the district that isn't hostile.
func _flood_lights() -> Array:
	return [
		[Vector3(-6, 4, -6), Color(1.0, 0.75, 0.45)],
		[Vector3(6, 4, 6), Color(1.0, 0.7, 0.4)],
		[Vector3(6, 4, -6), Color(0.4, 0.7, 1.0)],
	]

func _cover_layout() -> Array:
	return [
		[PROP_SHELF_WALL, -10.0, -8.0, 90.0], [PROP_SHELF, -10.0, -3.0, 90.0],
		[PROP_VENDING, 10.5, -6.0, 270.0], [PROP_CRATE, 9.0, 8.0, 30.0],
		[PROP_SHELF, 4.0, -10.5, 0.0],
	]

func _crew_spawns() -> Array:
	return [
		Vector3(-1.5, 0.1, 3.0), Vector3(1.5, 0.1, 3.0),
		Vector3(-1.5, 0.1, 6.0), Vector3(1.5, 0.1, 6.0),
	]

func _enemy_spawns() -> Array:
	return []  # the one safe place

func _build_extra_geometry() -> void:
	_build_map_console()
	# Practicals: the console's glow, and warm lamps over the shelves.
	add_practical_light(Vector3(0, 1.6, -5.5), Color(0.3, 0.9, 1.0), 1.6, 5.0)
	add_practical_light(Vector3(-9.5, 2.0, -5.0), Color(1.0, 0.72, 0.42), 1.4, 6.0)
	add_practical_light(Vector3(9.5, 1.8, -5.5), Color(1.0, 0.72, 0.42), 1.2, 5.0)

## The district-map console: a glowing terminal — the active character
## stepping up to it opens the map (M works anywhere too).
func _build_map_console() -> void:
	var console := StaticBody3D.new()
	console.collision_layer = Layers.COVER
	console.add_to_group(NavRuntime.SOURCE_GROUP)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.1, 0.6)
	col.shape = box
	col.position.y = 0.55
	console.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.12, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 1.0)
	mat.emission_energy_multiplier = 0.8
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = 0.55
	console.add_child(mi)
	var sign := Label3D.new()
	sign.text = "DISTRICT MAP"
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.outline_size = 8
	sign.modulate = Color(0.55, 0.95, 1.0)
	sign.position.y = 1.9
	console.add_child(sign)
	_level.add_child(console)
	console.global_position = Vector3(0.0, 0.0, -6.0)
	# Approach trigger.
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = Layers.SQUAD
	var zcol := CollisionShape3D.new()
	var zbox := BoxShape3D.new()
	zbox.size = Vector3(4.0, 2.0, 3.5)
	zcol.shape = zbox
	zone.add_child(zcol)
	_level.add_child(zone)
	zone.global_position = Vector3(0.0, 0.6, -4.0)
	zone.body_entered.connect(func(body: Node3D):
		if body is Character and body == _squad.active_character():
			DistrictMap.toggle(self, "hideout"))
