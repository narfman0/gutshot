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

func ground_params() -> Dictionary:
	# Wet asphalt slabs under the neon: big panels, oily standing water in
	# the low spots, grime in every joint. The most reflective street floor.
	return {"tile_size": 7.0, "grout_width": 0.012, "tile_variation": 0.10,
		"grime_amount": 0.65, "grime_scale": 0.11, "crack_amount": 0.25,
		"base_color": Color(0.23, 0.24, 0.27),
		"wet_amount": 0.85, "puddle_scale": 0.10,
		"base_roughness": 0.62, "wet_roughness": 0.045, "metallic_amount": 0.05}

const BLD_LARGE_01 := "res://assets/meshes/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Large_01.gltf"
const BLD_LARGE_03 := "res://assets/meshes/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Large_03.gltf"
const BLD_LARGE_05 := "res://assets/meshes/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Large_05.gltf"
const BLD_BANK := "res://assets/meshes/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Bank_01.gltf"
const BLD_FOODHOLE := "res://assets/meshes/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_FoodHole_01.gltf"
const BLD_CHOPSHOP := "res://assets/meshes/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Chopshop_01.gltf"

## Tenements and shopfronts crowding the crossroads — the street is a
## CANYON, not a courtyard. Everything sits outside the wall line so the
## playable floor is untouched; the gates stay clear.
func buildings() -> Array:
	return [
		[BLD_LARGE_01, -40.0, -1.0, 90.0], [BLD_LARGE_03, -40.0, 24.0, 90.0],
		[BLD_BANK, 40.0, -12.0, 270.0], [BLD_LARGE_05, 40.0, 24.0, 270.0],
		[BLD_FOODHOLE, -12.0, 38.0, 0.0], [BLD_CHOPSHOP, 12.0, 39.0, 0.0],
		[BLD_LARGE_01, 20.0, -40.0, 180.0],
	]

const ROOF_H := 4.5

func gates() -> Array:
	return [
		{"side": "w", "center": 15.0},  # alley to the hideout
		{"side": "e", "center": 10.0},  # arcade toward the Exchange
		{"side": "n", "center": -6.0},  # the plaza up to Vantag Tower
		{"side": "w", "center": -12.0},  # the market gate into Little Japan
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
		# One walker per ground pack, the rest anchored: a gang HOLDS a corner,
		# so a beat on every body would read like a garrison, not turf.
		{"skin": "punk", "pos": Vector3(-6.0, 0.1, -6.0), "pack": "mid", "morale": true,
			"patrol": [Vector3(-7.0, 0.1, -3.0), Vector3(2.0, 0.1, -9.0)]},
		{"skin": "biker", "pos": Vector3(-3.5, 0.1, -7.0), "pack": "mid", "morale": true},
		{"skin": "gangster", "pos": Vector3(9.0, 0.1, -12.0), "pack": "east", "morale": true,
			"patrol": [Vector3(12.0, 0.1, -6.0), Vector3(8.0, 0.1, -16.0)]},
		{"skin": "punk_girl", "pos": Vector3(11.0, 0.1, -11.0), "pack": "east", "morale": true,
			"gear": "res://resources/gear/enemy_pistol.tres"},
		{"skin": "punk", "pos": Vector3(-10.0, 0.1, -12.0), "pack": "west", "morale": true},
		{"skin": "biker", "pos": Vector3(-12.0, 0.1, -14.0), "pack": "west", "morale": true,
			"gear": "res://resources/gear/enemy_rifle.tres"},
		{"skin": "gangster", "pos": Vector3(0.0, 0.1, -17.0), "pack": "west", "morale": true},
		{"skin": "punk", "pos": Vector3(-14.0, 0.1, -10.0), "pack": "west", "morale": true,
			"gear": "res://resources/gear/scrap_blade.tres"},
		# The roof lookout — the crossroads belongs to whoever is up there.
		{"skin": "gangster", "pos": Vector3(-6.0, 4.65, -21.0), "pack": "roof",
			"morale": true, "aggro": 18.0, "xp": 15,
			"gear": "res://resources/gear/enemy_rifle.tres",
			"patrol": [Vector3(-14.0, ROOF_H, -21.5), Vector3(10.0, ROOF_H, -21.5)]},
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
	# The fire-escape roofline: a walkway over the north shopfronts, reached
	# by stairs at the west end. Whoever holds it holds the crossroads.
	add_walkable_box(Vector3(-2.0, ROOF_H - 0.15, -21.5), Vector3(30.0, 0.3, 7.0),
		0.0, 0.0, Color(0.22, 0.21, 0.22), 0.03)
	add_walkable_box(Vector3(-19.0, ROOF_H * 0.5 - 0.15, -16.0),
		Vector3(3.5, 0.3, 10.06), 26.57, 0.0, Color(0.22, 0.21, 0.22), 0.03)
	add_rail(Vector3(-2.0, ROOF_H + 0.4, -18.2), Vector3(30.0, 0.8, 0.08),
		Color(0.8, 0.45, 0.2), 0.35)
	add_practical_light(Vector3(-10.0, ROOF_H + 2.2, -21.0), Color(1.0, 0.6, 0.25), 1.3, 7.0)
	add_practical_light(Vector3(8.0, ROOF_H + 2.2, -21.0), Color(1.0, 0.6, 0.25), 1.3, 7.0)
	# Shopfront bays along the south frontage — cover you can back into.
	add_bay(Vector3(-8.0, 0, 23.5), 4.0, 180.0, Color(0.19, 0.18, 0.20), Color(0.3, 0.9, 1.0))
	add_bay(Vector3(4.0, 0, 23.5), 4.0, 180.0, Color(0.19, 0.18, 0.20), Color(1.0, 0.35, 0.8))
	add_bay(Vector3(-23.5, 0, 2.0), 4.0, 90.0, Color(0.19, 0.18, 0.20), Color(1.0, 0.65, 0.25))
	# Two shopfronts you can actually walk into — the chopshop's roller bay
	# and the noodle bar. Both open onto the street, both are ambush boxes.
	add_room(Vector3(-16.0, 0, -20.0), 9.0, 7.0, 0.0,
		Color(0.19, 0.17, 0.16), Color(1.0, 0.55, 0.2), "CHOP SHOP")
	add_decor(PROP_CRATE_04, Vector3(-19.0, 0, -22.0), 20.0)
	add_decor(PROP_TRASH_BIN, Vector3(-13.0, 0, -22.5), 60.0)
	add_room(Vector3(14.0, 0, -20.0), 8.0, 6.5, 0.0,
		Color(0.18, 0.16, 0.18), Color(0.3, 0.9, 1.0), "麺")
	add_decor(PROP_VENDING, Vector3(11.5, 0, -22.0), 0.0)
	# Idle life: steam off the grates.
	add_steam(Vector3(-6.0, 0, -2.0))
	add_steam(Vector3(14.0, 0, -14.0))
