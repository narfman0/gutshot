@tool
## The Hideout — the crew's bolt-hole in the district margins, the one safe
## place (docs/narrative.md). No enemies. Entering rests the crew: full heal,
## crew_state cleared, provocations forgiven. The map console shows the
## district (informational — travel is on foot).
extends SiteChunk

const PROP_SHELF := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Shelf_01.gltf"
const PROP_SHELF_WALL := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Shelf_Wall_01.gltf"
const PROP_VENDING := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Vending_Machine_01.gltf"
const PROP_CRATE := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_06.gltf"

func site_id() -> String:
	return "hideout"

func site_name() -> String:
	return "THE HIDEOUT"

func arena_half() -> float:
	return 12.0

func ground_color() -> Color:
	return Color(0.16, 0.14, 0.12)  # scuffed deck plating, almost warm

func heals_crew() -> bool:
	return true  # the safe room patches everyone up

func sun_energy() -> float:
	return 0.5

func fog_density() -> float:
	return 0.01  # close, smoky, safe

func sky_energy() -> float:
	return 0.04  # a buried bolt-hole: no sky, just ceiling

func ambient() -> String:
	return "ambient_hideout"  # the quietest air in the district

func ground_params() -> Dictionary:
	# Scavenged deck plating: small panels, heavy wear, a metal sheen and no
	# water — this floor is INSIDE, and somebody sweeps it.
	return {"tile_size": 2.2, "grout_width": 0.035, "tile_variation": 0.13,
		"grime_amount": 0.5, "grime_scale": 0.3, "crack_amount": 0.0,
		"base_color": Color(0.22, 0.19, 0.16),
		"wet_amount": 0.0, "base_roughness": 0.55, "metallic_amount": 0.35}

func gates() -> Array:
	return [{"side": "e", "center": 0.0}]  # the alley out toward the street

## Warm low light — the one place in the district that isn't hostile.
func flood_lights() -> Array:
	return [
		[Vector3(-6, 4, -6), Color(1.0, 0.75, 0.45)],
		[Vector3(6, 4, 6), Color(1.0, 0.7, 0.4)],
		[Vector3(6, 4, -6), Color(0.4, 0.7, 1.0)],
	]

func cover_layout() -> Array:
	return [
		[PROP_SHELF_WALL, -10.0, -8.0, 90.0], [PROP_SHELF, -10.0, -3.0, 90.0],
		[PROP_VENDING, 10.5, -6.0, 270.0], [PROP_CRATE, 9.0, 8.0, 30.0],
		[PROP_SHELF, 4.0, -10.5, 0.0],
	]

func crew_spawns() -> Array:
	return [
		Vector3(-1.5, 0.1, 3.0), Vector3(1.5, 0.1, 3.0),
		Vector3(-1.5, 0.1, 6.0), Vector3(1.5, 0.1, 6.0),
	]

const PROP_WORK_BENCH := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Work_Bench_01.gltf"
const PROP_CHAIR := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Computer_Chair_01.gltf"
const PROP_TABLE := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Small_Table_01.gltf"
const PROP_TRASH_BIN := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Trash_Bin_02.gltf"
const PROP_WIRES := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Wires_07.gltf"

func wall_color() -> Color:
	return Color(0.19, 0.16, 0.13)  # scavenged panelling, warm-ish

func build_extra_geometry() -> void:
	_build_map_console()
	# Practicals: the console's glow, and warm lamps over the shelves.
	add_practical_light(Vector3(0, 1.6, -5.5), Color(0.3, 0.9, 1.0), 1.6, 5.0)
	add_practical_light(Vector3(-9.5, 2.0, -5.0), Color(1.0, 0.72, 0.42), 1.4, 6.0)
	add_practical_light(Vector3(9.5, 1.8, -5.5), Color(1.0, 0.72, 0.42), 1.2, 5.0)
	# Lived-in clutter — somebody actually sleeps here.
	add_decor(PROP_WORK_BENCH, Vector3(-6.0, 0, -10.6), 5.0)
	add_decor(PROP_TABLE, Vector3(4.2, 0, -8.8), 30.0)
	add_decor(PROP_CHAIR, Vector3(3.2, 0, -7.6), 210.0)
	add_decor(PROP_TRASH_BIN, Vector3(11.0, 0, 3.0), 80.0)
	add_decor(PROP_WIRES, Vector3(-3.0, 2.2, -11.6), 0.0)
	add_neon_sign("STAY LOW", Vector3(0.0, 2.6, -11.4), Color(1.0, 0.62, 0.3),
		0.0, 48, true)
	add_practical_light(Vector3(0.0, 2.4, -10.4), Color(1.0, 0.6, 0.3), 1.1, 5.0, true)

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
	gen_root().add_child(console)
	console.position = Vector3(0.0, 0.0, -6.0)
	# Approach trigger.
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = Layers.SQUAD
	var zcol := CollisionShape3D.new()
	var zbox := BoxShape3D.new()
	zbox.size = Vector3(4.0, 2.0, 3.5)
	zcol.shape = zbox
	zone.add_child(zcol)
	gen_root().add_child(zone)
	zone.position = Vector3(0.0, 0.6, -4.0)
	zone.body_entered.connect(func(body: Node3D):
		if world != null and body is Character and body == world.active_character():
			# Owed perk picks take the console over; the map stays on M.
			if GameState.total_picks_owed() > 0:
				TrainingPanel.toggle(self, world)
			else:
				DistrictMap.toggle(self, site_id()))
