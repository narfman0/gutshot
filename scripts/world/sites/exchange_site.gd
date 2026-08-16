@tool
## The Exchange — a shuttered vertical market hall, bandit-run since the
## traders pulled out (docs/locations.md). The three-floor site: ground
## trading floor, mezzanine gallery firing down over the rails, closed-off
## counting house up top. The east passage runs
## UNDER the gallery deck toward Depot 9.
extends SiteChunk

const PROP_CRATE_01 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_01.gltf"
const PROP_CRATE_04 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_04.gltf"
const CONTAINER_SMALL := "res://assets/meshes/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Prop_Shipping_Container_Small_01.gltf"
const VEH_CART := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Vehicles/SM_Veh_Cart_01.gltf"
const ENV_JUNK_2 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Environment/SM_Env_Junk_Pile_02.gltf"
const ENV_CHERRY := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Environment/SM_Env_Hologram_Cherry_Tree_01.gltf"
const PROP_WIRES := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Wires_10.gltf"

const MEZZ_H := 3.0   # gallery walk height
const TOP_H := 6.0    # counting-house walk height
const DECK_T := 0.3
const RAMP_TILT := 26.57  # rise 3 over run 6 — same read as the depot ramps

## Worn hall boards, not the depot's neon deck — the big slabs would scream
## in full emissive cyan; the yellow rails carry the edge read instead.
const DECK_COL := Color(0.30, 0.29, 0.27)
const DECK_GLOW := 0.04

func site_id() -> String:
	return "exchange"

func site_name() -> String:
	return "THE EXCHANGE"

func arena_half() -> float:
	return 30.0

func ground_color() -> Color:
	return Color(0.21, 0.19, 0.17)  # trampled market-hall flagstone

func sun_energy() -> float:
	return 0.7  # skylights boarded over — this hall lights itself

func fog_density() -> float:
	return 0.006

func sky_energy() -> float:
	return 0.18  # the boarded skylights gape in places

func wall_color() -> Color:
	return Color(0.20, 0.18, 0.15)  # water-stained hall brick

func ambient() -> String:
	return "ambient_hall"  # wind through the boarded skylights

func ground_params() -> Dictionary:
	# Market-hall flagstone: mid-size worn slabs, cracked and filthy after
	# years of freight, damp where the roof gapes.
	return {"tile_size": 3.4, "grout_width": 0.03, "tile_variation": 0.16,
		"grime_amount": 0.72, "grime_scale": 0.16, "crack_amount": 0.65,
		"base_color": Color(0.30, 0.27, 0.24),
		"wet_amount": 0.25, "puddle_scale": 0.13,
		"base_roughness": 0.78, "metallic_amount": 0.0}

const BLD_MED_01 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_01.gltf"
const BLD_MED_04 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_03.gltf"
const BLD_RAISED := "res://assets/meshes/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Raised_01.gltf"

## The hall is wedged into a block — neighbours press against every wall.
func buildings() -> Array:
	return [
		[BLD_MED_01, -44.0, 8.0, 90.0], [BLD_MED_04, -44.0, -14.0, 90.0],
		[BLD_MED_04, 44.0, 20.0, 270.0], [BLD_RAISED, 44.0, -18.0, 270.0],
		[BLD_MED_01, -14.0, -44.0, 180.0], [BLD_MED_04, 14.0, -44.0, 180.0],
	]

func gates() -> Array:
	return [
		{"side": "w", "center": 25.0},  # arcade from the street (south of the ramp)
		{"side": "e", "center": 0.0},   # passage under the east gallery, to Depot 9
	]

## Dead neon over the stalls, one cold shaft where the skylight boards gape.
func flood_lights() -> Array:
	return [
		[Vector3(-14, 9, 4), Color(0.95, 0.3, 0.75)],
		[Vector3(14, 9, 4), Color(0.2, 0.8, 1.0)],
		[Vector3(0, 10, -12), Color(1.0, 0.65, 0.25)],
		[Vector3(0, 9, 20), Color(0.35, 0.7, 1.0)],
	]

func cover_layout() -> Array:
	return [
		# Ground: abandoned stalls and freight left mid-move.
		[PROP_CRATE_01, -6.0, 8.0, 15.0], [PROP_CRATE_04, 5.0, 10.0, 40.0],
		[PROP_CRATE_01, 12.0, 2.0, 70.0], [PROP_CRATE_04, -12.0, 0.0, 0.0],
		[PROP_CRATE_01, 0.0, -4.0, 25.0], [PROP_CRATE_04, 8.0, -10.0, 55.0],
		[PROP_CRATE_01, -9.0, -12.0, 10.0], [CONTAINER_SMALL, -2.0, 14.0, 90.0],
		[PROP_CRATE_04, 14.0, 12.0, 20.0], [PROP_CRATE_01, -15.0, 8.0, 35.0],
		# Mezzanine gallery: cover the guards pop from (5th element = floor y).
		[PROP_CRATE_04, -26.0, -6.0, 20.0, MEZZ_H],
		[PROP_CRATE_04, 26.0, -4.0, 70.0, MEZZ_H],
		[PROP_CRATE_01, 6.0, -25.5, 10.0, MEZZ_H],
		[PROP_CRATE_04, -12.0, -25.5, 45.0, MEZZ_H],
		# Counting house: the last stand's furniture.
		[PROP_CRATE_01, -4.0, -23.0, 30.0, TOP_H],
		[PROP_CRATE_04, 6.0, -27.0, 60.0, TOP_H],
	]

func crew_spawns() -> Array:
	return [
		Vector3(-2.5, 0.1, 25.0), Vector3(0.0, 0.1, 26.0),
		Vector3(2.5, 0.1, 25.0), Vector3(0.0, 0.1, 23.5),
	]

func enemy_spawns() -> Array:
	return [
		# Trading floor pack — works the stalls.
		{"skin": "punk", "pos": Vector3(-8.0, 0.1, 2.0), "pack": "floor", "morale": true,
			"patrol": [Vector3(-12.0, 0.1, 6.0), Vector3(10.0, 0.1, 4.0), Vector3(0.0, 0.1, -8.0)]},
		{"skin": "biker", "pos": Vector3(8.0, 0.1, -2.0), "pack": "floor", "morale": true,
			"gear": "res://resources/gear/enemy_pistol.tres",
			"patrol": [Vector3(12.0, 0.1, -6.0), Vector3(-10.0, 0.1, -4.0)]},
		{"skin": "gangster", "pos": Vector3(0.0, 0.1, -12.0), "pack": "floor", "morale": true},
		# The stall-jumper: a blade rusher hiding among the crates.
		{"skin": "punk", "pos": Vector3(4.0, 0.1, 2.0), "pack": "floor", "morale": true,
			"gear": "res://resources/gear/scrap_blade.tres"},
		# Gallery watch — fires down over the rails; longer sight so the
		# atrium below is actually watched.
		{"skin": "gangster", "pos": Vector3(-26.0, 3.1, -10.0), "pack": "gallery",
			"morale": true, "aggro": 16.0,
			"patrol": [Vector3(-26.0, MEZZ_H, 10.0), Vector3(-26.0, MEZZ_H, -18.0),
				Vector3(-12.0, MEZZ_H, -25.5)]},
		{"skin": "punk_girl", "pos": Vector3(26.0, 3.1, -10.0), "pack": "gallery",
			"morale": true, "aggro": 16.0,
			"patrol": [Vector3(26.0, MEZZ_H, 8.0), Vector3(26.0, MEZZ_H, -18.0)]},
		{"skin": "punk", "pos": Vector3(10.0, 3.1, -25.5), "pack": "gallery",
			"morale": true, "aggro": 16.0,
			"patrol": [Vector3(18.0, MEZZ_H, -25.5), Vector3(-16.0, MEZZ_H, -25.5)]},
		# Counting house — the take is up here. Cornered; no morale test.
		{"skin": "biker", "pos": Vector3(-5.0, 6.1, -25.0), "pack": "vault", "pursue": false},
		{"skin": "gangster", "pos": Vector3(5.0, 6.1, -27.0), "pack": "vault", "pursue": false},
		{"skin": "punk", "pos": Vector3(0.0, 6.1, -23.0), "pack": "vault", "pursue": false},
	]

func build_extra_geometry() -> void:
	_build_gallery()
	_build_counting_house()
	# Practicals — sodium pools over the stalls, cyan strips under the
	# gallery decks (kept just below the assignment slack so they stay with
	# the ground floor they light), warm lamps above.
	add_practical_light(Vector3(0, 2.2, 5), Color(1.0, 0.6, 0.25), 1.8, 8.0)
	add_practical_light(Vector3(-8, 2.2, -4), Color(1.0, 0.6, 0.25), 1.6, 7.0)
	add_practical_light(Vector3(8, 2.2, -4), Color(1.0, 0.6, 0.25), 1.6, 7.0)
	add_practical_light(Vector3(-21, 2.5, -3), Color(0.25, 0.85, 1.0), 1.2, 6.0)
	add_practical_light(Vector3(21, 2.5, -3), Color(0.25, 0.85, 1.0), 1.2, 6.0)
	add_practical_light(Vector3(0, 2.5, -20), Color(0.25, 0.85, 1.0), 1.2, 6.0)
	add_practical_light(Vector3(-26, 4.5, -10), Color(1.0, 0.65, 0.3), 1.4, 7.0)
	add_practical_light(Vector3(26, 4.5, -10), Color(1.0, 0.65, 0.3), 1.4, 7.0)
	add_practical_light(Vector3(0, 4.5, -25.5), Color(1.0, 0.65, 0.3), 1.4, 7.0)
	add_practical_light(Vector3(0.5, 7.5, -25), Color(1.0, 0.45, 0.3), 1.6, 8.0)
	# The dead market: abandoned stall carts, junk in the corners, and one
	# hologram cherry tree still cycling in the atrium — nobody turned it off.
	add_decor(VEH_CART, Vector3(-8.0, 0, 16.5), 25.0)
	add_decor(VEH_CART, Vector3(11.0, 0, 17.0), 335.0)
	add_decor(ENV_JUNK_2, Vector3(-17.0, 0, -16.0), 50.0)
	add_decor(ENV_JUNK_2, Vector3(17.5, 0, 7.0), 190.0)
	add_decor(ENV_CHERRY, Vector3(1.5, 0, 7.5), 0.0)
	add_practical_light(Vector3(1.5, 2.6, 7.5), Color(1.0, 0.5, 0.75), 1.3, 7.0)
	add_decor(PROP_WIRES, Vector3(-21.6, 2.4, 4.0), 90.0)
	add_neon_sign("市場 THE EXCHANGE", Vector3(-29.3, 4.4, 6.0), Color(0.4, 0.9, 1.0),
		-90.0, 72, true)
	add_practical_light(Vector3(-28.2, 4.2, 6.0), Color(0.4, 0.9, 1.0), 1.4, 7.0, true)
	add_steam(Vector3(12.0, 0, -2.0))
	add_steam(Vector3(-6.0, 0, 12.5))

## U-shaped gallery hugging the north, west, and east walls, one deck height
## up, with ramps rising along the west and east walls. Railings on the inner
## (atrium) edges are visual-only — guards shoot over them, bodies drop past.
func _build_gallery() -> void:
	var deck_y := MEZZ_H - DECK_T * 0.5
	add_walkable_box(Vector3(0.0, deck_y, -25.5), Vector3(60.0, DECK_T, 9.0),
		0.0, 0.0, DECK_COL, DECK_GLOW)   # north
	add_walkable_box(Vector3(-26.0, deck_y, -3.0), Vector3(8.0, DECK_T, 36.0),
		0.0, 0.0, DECK_COL, DECK_GLOW)   # west
	add_walkable_box(Vector3(26.0, deck_y, -3.0), Vector3(8.0, DECK_T, 36.0),
		0.0, 0.0, DECK_COL, DECK_GLOW)   # east
	# Ramps: ground at z≈21 rising north to the deck at z≈15.
	add_walkable_box(Vector3(-26.0, MEZZ_H * 0.5 - 0.15, 18.0), Vector3(4.0, DECK_T, 6.7),
		RAMP_TILT, 0.0, DECK_COL, DECK_GLOW)
	add_walkable_box(Vector3(26.0, MEZZ_H * 0.5 - 0.15, 18.0), Vector3(4.0, DECK_T, 6.7),
		RAMP_TILT, 0.0, DECK_COL, DECK_GLOW)
	add_rail(Vector3(0.0, MEZZ_H + 0.35, -21.0), Vector3(44.0, 0.7, 0.06))
	add_rail(Vector3(-22.0, MEZZ_H + 0.35, -3.0), Vector3(0.06, 0.7, 36.0))
	add_rail(Vector3(22.0, MEZZ_H + 0.35, -3.0), Vector3(0.06, 0.7, 36.0))

## The counting house: a walled room over the north gallery, reached by a
## ramp on the deck below. Its slab and walls sit in the top floor group, so
## the whole room stays hidden until the climb reveals it.
func _build_counting_house() -> void:
	# Slab spans x -12..13 (the extra metre takes the ramp landing), z -30..-20.
	add_walkable_box(Vector3(0.5, TOP_H - DECK_T * 0.5, -25.0), Vector3(25.0, DECK_T, 10.0),
		0.0, 0.0, DECK_COL, DECK_GLOW)
	# Ramp on the north deck: deck at x≈19.4 rising west to the slab at x≈12.7.
	add_walkable_box(Vector3(16.0, (MEZZ_H + TOP_H) * 0.5 - 0.15, -25.5),
		Vector3(6.7, DECK_T, 4.0), 0.0, -RAMP_TILT, DECK_COL, DECK_GLOW)
	# Walls — door gap on the east side where the ramp lands.
	_house_wall(Vector3(0.5, 0.0, -20.2), Vector3(25.0, 2.4, 0.4))    # south
	_house_wall(Vector3(0.5, 0.0, -29.8), Vector3(25.0, 2.4, 0.4))    # north
	_house_wall(Vector3(-12.2, 0.0, -25.0), Vector3(0.4, 2.4, 10.0))  # west
	_house_wall(Vector3(13.2, 0.0, -28.5), Vector3(0.4, 2.4, 3.0))    # east, north of the door
	_house_wall(Vector3(13.2, 0.0, -22.0), Vector3(0.4, 2.4, 4.0))    # east, south of the door

func _house_wall(pos: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.COVER
	wall.add_to_group(NavRuntime.SOURCE_GROUP)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position.y = size.y * 0.5
	wall.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.28, 0.26)
	mat.roughness = 0.8
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = size.y * 0.5
	wall.add_child(mi)
	gen_root().add_child(wall)
	wall.position = Vector3(pos.x, TOP_H, pos.z)
