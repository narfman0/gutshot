@tool
## The Street — the neon crossroads under the tower, gang turf (the original
## M1 skirmish arena). Site id stays "skirmish" for save/map continuity.
extends SiteChunk

const PROP_CRATE_01 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_01.gltf"
const PROP_CRATE_04 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_04.gltf"
const PROP_CRATE_06 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_06.gltf"
const PROP_VENDING := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Vending_Machine_01.gltf"
const VEH_SUV := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Vehicles/SM_Veh_SUV_01.gltf"
const VEH_FOOD_TRUCK := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Vehicles/SM_Veh_Food_Truck_01.gltf"
const PROP_TRASH_SKIP := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Trash_Skip_01.gltf"
const PROP_STREET_LIGHT := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Street_Light_01.gltf"
const PROP_TRAFFIC := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Traffic_Lights_01.gltf"
const PROP_HOLO_SIGN := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Holo_Sign_01.gltf"
const PROP_WIRES := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Wires_03.gltf"
const PROP_TRASH_BIN := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Trash_Bin_01.gltf"
const ENV_JUNK := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Environment/SM_Env_Junk_Pile_01.gltf"

func site_id() -> String:
	return "skirmish"

func site_name() -> String:
	return "THE STREET"

func fog_density() -> float:
	return 0.0025  # thin night haze around the neon

func wall_color() -> Color:
	return Color(0.17, 0.17, 0.20)  # rain-stained ferrocrete

func gates() -> Array:
	return [
		{"side": "w", "center": 15.0},  # alley to the hideout
		{"side": "e", "center": 10.0},  # arcade toward the Exchange
	]

func flood_lights() -> Array:
	return [
		[Vector3(-18, 6, -18), Color(0.2, 0.8, 1.0)],
		[Vector3(18, 6, -18), Color(0.95, 0.3, 0.75)],
		[Vector3(-18, 6, 18), Color(0.95, 0.3, 0.75)],
		[Vector3(18, 6, 18), Color(0.2, 0.8, 1.0)],
	]

func cover_layout() -> Array:
	return [
		[PROP_CRATE_01, -8.0, 8.0, 0.0], [PROP_CRATE_04, -6.5, 8.5, 35.0],
		[PROP_CRATE_06, 7.0, 9.0, 0.0], [PROP_CRATE_01, 9.0, 8.0, 90.0],
		[PROP_VENDING, 0.0, 4.0, 180.0], [PROP_VENDING, 1.4, 4.0, 180.0],
		[PROP_CRATE_04, -12.0, 0.0, 15.0], [PROP_CRATE_01, 12.0, -1.0, 70.0],
		[PROP_CRATE_06, -4.0, -3.0, 0.0], [PROP_CRATE_01, 4.5, -4.0, 20.0],
		[PROP_VENDING, -9.0, -8.0, 90.0], [PROP_CRATE_04, -8.0, -9.5, 0.0],
		[PROP_CRATE_01, 8.5, -10.0, 45.0], [PROP_CRATE_06, 10.0, -8.5, 0.0],
		[PROP_CRATE_04, 0.0, -12.0, 60.0], [PROP_VENDING, 3.0, -15.0, 0.0],
		# Parked junk — the street's big cover pieces.
		[VEH_SUV, -18.0, 13.0, 40.0], [VEH_FOOD_TRUCK, 16.0, 16.0, 100.0],
		[PROP_TRASH_SKIP, -17.0, -18.0, 75.0],
	]

## Space-bandit flavor: looted mixed guns, a blade rusher in the west pack,
## and morale (they crack early — the spawner's bandit nerve default).
func enemy_spawns() -> Array:
	return [
		{"skin": "punk", "pos": Vector3(-6.0, 0.1, -6.0), "pack": "mid", "morale": true},
		{"skin": "biker", "pos": Vector3(-3.5, 0.1, -7.0), "pack": "mid", "morale": true},
		{"skin": "gangster", "pos": Vector3(9.0, 0.1, -12.0), "pack": "east", "morale": true},
		{"skin": "punk_girl", "pos": Vector3(11.0, 0.1, -11.0), "pack": "east", "morale": true,
			"gear": "res://resources/gear/enemy_pistol.tres"},
		{"skin": "punk", "pos": Vector3(-10.0, 0.1, -12.0), "pack": "west", "morale": true},
		{"skin": "biker", "pos": Vector3(-12.0, 0.1, -14.0), "pack": "west", "morale": true,
			"gear": "res://resources/gear/enemy_rifle.tres"},
		{"skin": "gangster", "pos": Vector3(0.0, 0.1, -17.0), "pack": "west", "morale": true},
		{"skin": "punk", "pos": Vector3(-14.0, 0.1, -10.0), "pack": "west", "morale": true,
			"gear": "res://resources/gear/scrap_blade.tres"},
	]

func build_extra_geometry() -> void:
	# Practicals: the vending machines throw light like storefronts, and the
	# central crate cluster gets a magenta wash.
	add_practical_light(Vector3(0.7, 1.6, 4.6), Color(0.3, 0.9, 1.0), 1.6, 6.0)
	add_practical_light(Vector3(-9.0, 1.6, -7.4), Color(0.3, 0.9, 1.0), 1.4, 6.0)
	add_practical_light(Vector3(3.0, 1.6, -14.4), Color(0.95, 0.3, 0.75), 1.4, 6.0)
	add_practical_light(Vector3(0, 1.2, -8.0), Color(0.95, 0.3, 0.75), 1.0, 7.0)
	# Street furniture: lamps at the corners (paired with their own pools),
	# a dead traffic signal, junk where the crowd never cleans.
	for corner in [Vector3(-21, 0, 21), Vector3(21, 0, 21),
			Vector3(-21, 0, -21), Vector3(21, 0, -21)]:
		add_decor(PROP_STREET_LIGHT, corner, 45.0)
		add_practical_light(corner + Vector3(0, 3.4, 0), Color(1.0, 0.85, 0.6), 1.3, 8.0)
	add_decor(PROP_TRAFFIC, Vector3(4.0, 0, 18.0), 200.0)
	add_decor(PROP_HOLO_SIGN, Vector3(-4.5, 0, 2.0), 25.0)
	add_decor(PROP_TRASH_BIN, Vector3(12.5, 0, 3.0), 10.0)
	add_decor(ENV_JUNK, Vector3(-22.0, 0, -22.0), 20.0)
	add_decor(PROP_WIRES, Vector3(-8.0, 2.6, -24.6), 0.0)
	add_decor(PROP_WIRES, Vector3(14.0, 2.6, -24.6), 0.0)
	# The street talks: dying neon on the tall walls.
	add_neon_sign("麺 NOODLES", Vector3(-12.0, 2.3, -24.3), Color(0.3, 0.95, 1.0),
		0.0, 64, true)
	add_neon_sign("MOTEL ◉", Vector3(7.0, 2.5, -24.3), Color(1.0, 0.35, 0.8),
		0.0, 64, true)
	add_neon_sign("バー BAR", Vector3(-24.3, 2.4, 6.0), Color(1.0, 0.65, 0.25),
		-90.0, 56, true)
	add_practical_light(Vector3(-12.0, 2.3, -23.4), Color(0.3, 0.95, 1.0), 1.5, 6.0, true)
	add_practical_light(Vector3(7.0, 2.5, -23.4), Color(1.0, 0.35, 0.8), 1.5, 6.0, true)
	# Idle life: steam off the grates.
	add_steam(Vector3(-6.0, 0, -2.0))
	add_steam(Vector3(14.0, 0, -14.0))
