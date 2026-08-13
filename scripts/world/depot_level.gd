## Depot 9 — Vantag's logistics warehouse, quietly run by bandit crews
## (docs/locations.md). The Phase-2 systems testbed:
##   · a dividing wall with two BREACH DOORS (shoot/blast through, navmesh
##     re-bakes when they blow)
##   · a CATWALK crossing over the wall — the alternate route, patrolled
##   · container aisles (full cover), bandit packs with PATROLS and MORALE
##     (thin a pack to half and the survivors break and run)
## Transit pad returns to the street skirmish.
extends GameWorld

const CONTAINER := "res://assets/meshes/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Prop_Shipping_Container_01.gltf"
const CONTAINER_SMALL := "res://assets/meshes/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Prop_Shipping_Container_Small_01.gltf"
const PROP_CRATE_01 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_01.gltf"
const PROP_CRATE_04 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_04.gltf"

const WALL_Z := -4.0
const WALL_H := 2.4
const DECK_H := 2.6

func _arena_half() -> float:
	return 26.0

func _ground_color() -> Color:
	return Color(0.20, 0.20, 0.19)  # stained warehouse concrete

func _cover_layout() -> Array:
	return [
		# Yard (crew side): scattered crates for the approach fight.
		[PROP_CRATE_01, -9.0, 8.0, 20.0], [PROP_CRATE_04, -7.5, 9.0, 0.0],
		[PROP_CRATE_01, 8.0, 6.0, 75.0], [PROP_CRATE_04, 12.0, 12.0, 40.0],
		[PROP_CRATE_01, 0.0, 12.0, 10.0],
		# Back warehouse: container aisles running north-south.
		[CONTAINER, -16.0, -12.0, 0.0], [CONTAINER, -16.0, -19.0, 0.0],
		[CONTAINER, -8.0, -14.0, 0.0], [CONTAINER, -8.0, -21.0, 0.0],
		[CONTAINER, 8.0, -12.0, 0.0], [CONTAINER, 8.0, -19.0, 0.0],
		[CONTAINER, 16.0, -14.0, 0.0], [CONTAINER, 16.0, -21.0, 0.0],
		[CONTAINER_SMALL, 0.0, -16.0, 90.0], [CONTAINER_SMALL, 2.5, -20.0, 0.0],
		[PROP_CRATE_04, -12.0, -9.0, 55.0], [PROP_CRATE_01, 12.0, -8.0, 15.0],
	]

func _crew_spawns() -> Array:
	return [
		Vector3(-2.5, 0.1, 21.0), Vector3(0.0, 0.1, 22.0),
		Vector3(2.5, 0.1, 21.0), Vector3(0.0, 0.1, 19.5),
	]

func _enemy_spawns() -> Array:
	return [
		# Yard patrol — walks the fence line.
		{"skin": "punk", "pos": Vector3(-10.0, 0.1, 2.0), "pack": "yard", "morale": true,
			"patrol": [Vector3(-14.0, 0.1, 2.0), Vector3(14.0, 0.1, 2.0), Vector3(0.0, 0.1, 8.0)]},
		{"skin": "biker", "pos": Vector3(10.0, 0.1, 2.0), "pack": "yard", "morale": true,
			"patrol": [Vector3(14.0, 0.1, 2.0), Vector3(-14.0, 0.1, 2.0)]},
		# Catwalk watch — owns the high route.
		{"skin": "gangster", "pos": Vector3(0.0, 0.1, -9.0), "pack": "walk", "morale": true,
			"patrol": [Vector3(0.0, DECK_H, -9.0), Vector3(0.0, DECK_H, 1.0)]},
		{"skin": "punk_girl", "pos": Vector3(2.0, 0.1, -11.0), "pack": "walk", "morale": true},
		# Back-room crew among the containers.
		{"skin": "biker", "pos": Vector3(-12.0, 0.1, -16.0), "pack": "back", "morale": true},
		{"skin": "gangster", "pos": Vector3(4.0, 0.1, -18.0), "pack": "back", "morale": true},
		{"skin": "punk", "pos": Vector3(12.0, 0.1, -17.0), "pack": "back", "morale": true},
	]

func _build_extra_geometry() -> void:
	_build_dividing_wall()
	_build_catwalk()
	add_transit_zone(Vector3(22.0, 0.0, 22.0), "skirmish", "→ STREET")

## Full-height wall across the arena at WALL_Z with two door gaps; the doors
## are BreachDoors. Wall sits UNDER the catwalk crossing at x = 0.
func _build_dividing_wall() -> void:
	var half := _arena_half()
	# Segments: [-half..-10], [-6..6], [10..half] — gaps at ±8 (width 4).
	for seg in [[-half, -10.0], [-6.0, 6.0], [10.0, half]]:
		var from: float = seg[0]
		var to: float = seg[1]
		var wall := StaticBody3D.new()
		wall.collision_layer = Layers.COVER
		wall.add_to_group(NavRuntime.SOURCE_GROUP)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(to - from, WALL_H, 0.6)
		col.shape = box
		col.position.y = WALL_H * 0.5
		wall.add_child(col)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.33, 0.35)
		mat.roughness = 0.8
		mesh.material = mat
		mi.mesh = mesh
		mi.position.y = WALL_H * 0.5
		wall.add_child(mi)
		_level.add_child(wall)
		wall.global_position = Vector3((from + to) * 0.5, 0.0, WALL_Z)
	BreachDoor.build(_level, Vector3(-8.0, 0.0, WALL_Z), Vector3(4.0, WALL_H, 0.5))
	BreachDoor.build(_level, Vector3(8.0, 0.0, WALL_Z), Vector3(4.0, WALL_H, 0.5))

## Deck over the wall at x = 0 with ramps at both ends — the loud doors'
## quiet alternative, if you can take it from the watch.
func _build_catwalk() -> void:
	_walkable_box(Vector3(0, DECK_H - 0.15, -4.0), Vector3(3.0, 0.3, 12.0), 0.0)
	# South ramp: ground at z≈7 rising to the deck at z≈2.
	_walkable_box(Vector3(0, DECK_H * 0.5 - 0.15, 4.6), Vector3(3.0, 0.3, 5.9), 27.5)
	# North ramp: ground at z≈-15 rising to the deck at z≈-10.
	_walkable_box(Vector3(0, DECK_H * 0.5 - 0.15, -12.6), Vector3(3.0, 0.3, 5.9), -27.5)

func _walkable_box(pos: Vector3, size: Vector3, tilt_deg: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.GROUND
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
	mat.albedo_color = Color(0.25, 0.28, 0.30)
	mat.roughness = 0.5
	mat.metallic = 0.5
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 0.15
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	_level.add_child(body)
	body.global_position = pos
	body.rotation.x = deg_to_rad(tilt_deg)
