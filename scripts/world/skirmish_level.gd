## The M1 street-skirmish arena — GameWorld with the original CyberCity
## crate layout. Now one site among several: a transit pad links to Depot 9.
extends GameWorld

const PROP_CRATE_01 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_01.gltf"
const PROP_CRATE_04 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_04.gltf"
const PROP_CRATE_06 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_06.gltf"
const PROP_VENDING := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Vending_Machine_01.gltf"

func _cover_layout() -> Array:
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

func _enemy_spawns() -> Array:
	return [
		{"skin": "punk", "pos": Vector3(-6.0, 0.1, -6.0), "pack": "mid"},
		{"skin": "biker", "pos": Vector3(-3.5, 0.1, -7.0), "pack": "mid"},
		{"skin": "gangster", "pos": Vector3(9.0, 0.1, -12.0), "pack": "east"},
		{"skin": "punk_girl", "pos": Vector3(11.0, 0.1, -11.0), "pack": "east"},
		{"skin": "punk", "pos": Vector3(-10.0, 0.1, -12.0), "pack": "west"},
		{"skin": "biker", "pos": Vector3(-12.0, 0.1, -14.0), "pack": "west"},
		{"skin": "gangster", "pos": Vector3(0.0, 0.1, -17.0), "pack": "west"},
	]

func _site_name() -> String:
	return "THE STREET"

func _site_id() -> String:
	return "skirmish"

func _fog_density() -> float:
	return 0.0025  # thin night haze around the neon

func _build_extra_geometry() -> void:
	add_transit_zone(Vector3(20.0, 0.0, 20.0), "depot", "→ DEPOT 9")
	add_transit_zone(Vector3(-20.0, 0.0, 20.0), "hideout", "→ HIDEOUT")
	# Practicals: the vending machines throw light like storefronts, and the
	# central crate cluster gets a magenta wash.
	add_practical_light(Vector3(0.7, 1.6, 4.6), Color(0.3, 0.9, 1.0), 1.6, 6.0)
	add_practical_light(Vector3(-9.0, 1.6, -7.4), Color(0.3, 0.9, 1.0), 1.4, 6.0)
	add_practical_light(Vector3(3.0, 1.6, -14.4), Color(0.95, 0.3, 0.75), 1.4, 6.0)
	add_practical_light(Vector3(0, 1.2, -8.0), Color(0.95, 0.3, 0.75), 1.0, 7.0)
