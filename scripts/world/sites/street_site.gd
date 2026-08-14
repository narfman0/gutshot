@tool
## The Street — the neon crossroads under the tower, gang turf (the original
## M1 skirmish arena). Site id stays "skirmish" for save/map continuity.
extends SiteChunk

const PROP_CRATE_01 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_01.gltf"
const PROP_CRATE_04 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_04.gltf"
const PROP_CRATE_06 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_06.gltf"
const PROP_VENDING := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Vending_Machine_01.gltf"

func site_id() -> String:
	return "skirmish"

func site_name() -> String:
	return "THE STREET"

func fog_density() -> float:
	return 0.0025  # thin night haze around the neon

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
	]

func enemy_spawns() -> Array:
	return [
		{"skin": "punk", "pos": Vector3(-6.0, 0.1, -6.0), "pack": "mid"},
		{"skin": "biker", "pos": Vector3(-3.5, 0.1, -7.0), "pack": "mid"},
		{"skin": "gangster", "pos": Vector3(9.0, 0.1, -12.0), "pack": "east"},
		{"skin": "punk_girl", "pos": Vector3(11.0, 0.1, -11.0), "pack": "east"},
		{"skin": "punk", "pos": Vector3(-10.0, 0.1, -12.0), "pack": "west"},
		{"skin": "biker", "pos": Vector3(-12.0, 0.1, -14.0), "pack": "west"},
		{"skin": "gangster", "pos": Vector3(0.0, 0.1, -17.0), "pack": "west"},
	]

func build_extra_geometry() -> void:
	# Practicals: the vending machines throw light like storefronts, and the
	# central crate cluster gets a magenta wash.
	add_practical_light(Vector3(0.7, 1.6, 4.6), Color(0.3, 0.9, 1.0), 1.6, 6.0)
	add_practical_light(Vector3(-9.0, 1.6, -7.4), Color(0.3, 0.9, 1.0), 1.4, 6.0)
	add_practical_light(Vector3(3.0, 1.6, -14.4), Color(0.95, 0.3, 0.75), 1.4, 6.0)
	add_practical_light(Vector3(0, 1.2, -8.0), Color(0.95, 0.3, 0.75), 1.0, 7.0)
