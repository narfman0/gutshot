@tool
## Depot 9 — Vantag's logistics warehouse, quietly run by bandit crews
## (docs/locations.md): dividing wall with two BREACH DOORS, catwalk over it,
## container aisles, patrols + morale. West arcade to the Exchange, south
## freight tunnel to the Fab Level.
extends SiteChunk

const CONTAINER := "res://assets/meshes/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Prop_Shipping_Container_01.gltf"
const CONTAINER_SMALL := "res://assets/meshes/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Prop_Shipping_Container_Small_01.gltf"
const PROP_CRATE_01 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_01.gltf"
const PROP_CRATE_04 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_04.gltf"

const WALL_Z := -4.0
const DIV_WALL_H := 2.4
const DECK_H := 2.6

func site_id() -> String:
	return "depot"

func site_name() -> String:
	return "DEPOT 9"

func arena_half() -> float:
	return 26.0

func ground_color() -> Color:
	return Color(0.20, 0.20, 0.19)  # stained warehouse concrete

func sun_energy() -> float:
	return 0.9  # dimmer skylight leak — this is an interior

func fog_density() -> float:
	return 0.007  # warehouse dust hanging in the work-lights

func ambient() -> String:
	return "ambient_industrial"  # thrum, ducts, the conveyor's slow thud

func gates() -> Array:
	return [
		{"side": "w", "center": 0.0},    # arcade from the Exchange
		{"side": "s", "center": -14.0},  # freight tunnel to the Fab Level
	]

## Sodium work-lights over the aisles, one cold blue over the yard gate.
func flood_lights() -> Array:
	return [
		[Vector3(-12, 6, -14), Color(1.0, 0.65, 0.25)],
		[Vector3(12, 6, -14), Color(1.0, 0.65, 0.25)],
		[Vector3(0, 6, -6), Color(1.0, 0.55, 0.2)],
		[Vector3(0, 6, 12), Color(0.35, 0.7, 1.0)],
		[Vector3(18, 6, 18), Color(0.2, 0.8, 1.0)],
	]

func cover_layout() -> Array:
	return [
		# Yard (south side): scattered crates for the approach fight.
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

func crew_spawns() -> Array:
	return [
		Vector3(-2.5, 0.1, 21.0), Vector3(0.0, 0.1, 22.0),
		Vector3(2.5, 0.1, 21.0), Vector3(0.0, 0.1, 19.5),
	]

func enemy_spawns() -> Array:
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

func build_extra_geometry() -> void:
	_build_dividing_wall()
	_build_catwalk()
	# Practicals: cyan strips under the catwalk deck, glow pooled in the
	# container aisles where the fights happen.
	add_practical_light(Vector3(0, 1.8, -7.5), Color(0.25, 0.85, 1.0), 1.2, 5.0)
	add_practical_light(Vector3(0, 1.8, -0.5), Color(0.25, 0.85, 1.0), 1.2, 5.0)
	add_practical_light(Vector3(-12, 2.5, -16), Color(1.0, 0.6, 0.25), 1.8, 8.0)
	add_practical_light(Vector3(12, 2.5, -16), Color(1.0, 0.6, 0.25), 1.8, 8.0)

## Full-height wall across the site at WALL_Z with two door gaps; the doors
## are BreachDoors. Wall sits UNDER the catwalk crossing at x = 0.
func _build_dividing_wall() -> void:
	var half := arena_half()
	# Segments: [-half..-10], [-6..6], [10..half] — gaps at ±8 (width 4).
	for seg in [[-half, -10.0], [-6.0, 6.0], [10.0, half]]:
		var from: float = seg[0]
		var to: float = seg[1]
		var wall := StaticBody3D.new()
		wall.collision_layer = Layers.COVER
		wall.add_to_group(NavRuntime.SOURCE_GROUP)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(to - from, DIV_WALL_H, 0.6)
		col.shape = box
		col.position.y = DIV_WALL_H * 0.5
		wall.add_child(col)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.33, 0.35)
		mat.roughness = 0.8
		mesh.material = mat
		mi.mesh = mesh
		mi.position.y = DIV_WALL_H * 0.5
		wall.add_child(mi)
		gen_root().add_child(wall)
		wall.position = Vector3((from + to) * 0.5, 0.0, WALL_Z)
	BreachDoor.build(gen_root(), Vector3(-8.0, 0.0, WALL_Z), Vector3(4.0, DIV_WALL_H, 0.5))
	BreachDoor.build(gen_root(), Vector3(8.0, 0.0, WALL_Z), Vector3(4.0, DIV_WALL_H, 0.5))

## Deck over the wall at x = 0 with ramps at both ends — the loud doors'
## quiet alternative, if you can take it from the watch.
func _build_catwalk() -> void:
	add_walkable_box(Vector3(0, DECK_H - 0.15, -4.0), Vector3(3.0, 0.3, 12.0))
	# South ramp: ground at z≈7 rising to the deck at z≈2.
	add_walkable_box(Vector3(0, DECK_H * 0.5 - 0.15, 4.6), Vector3(3.0, 0.3, 5.9), 27.5)
	# North ramp: ground at z≈-15 rising to the deck at z≈-10.
	add_walkable_box(Vector3(0, DECK_H * 0.5 - 0.15, -12.6), Vector3(3.0, 0.3, 5.9), -27.5)
	for rail_x in [-1.5, 1.5]:
		add_rail(Vector3(rail_x, DECK_H + 0.35, -4.0), Vector3(0.06, 0.7, 12.0))
