@tool
## Little Japan — the street level under the tower's shadow (docs/locations
## .md): noodle stalls, neon, shrine alleys, and the Clan that polices all
## of it. The POLYGON_CyberCity Japanese-cyberpunk identity at full strength,
## with the Samurai pack's shrine, torii, lanterns and market stands doing
## the heavy lifting.
##
## The busiest site in the district by design — it is the one place with
## CIVILIANS in it, and the encounter is a three-way waiting to happen:
##   · market crowd — geisha, villagers, unarmed, they scatter when it starts
##   · clan patrol — ninjato + SILENT shuriken, they vanish in smoke when hurt
##   · rooftop watch — shuriken throwers on the shop roofs (FloorSystem tier)
##   · gang incursion — bandits shaking down the south stalls; the clan is
##     already base-hostile to them, so walking in on that fight is free
##   · the sensei at the shrine — deep HP, katana, the clan's authority
##
## Clan honor: hurt one and the grudge does NOT wash out at the hideout
## (Factions.note_attack routes CLAN through provoke_lasting).
extends SiteChunk

# CyberCity (the street's own vocabulary)
const PROP_VENDING := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Vending_Machine_01.gltf"
const PROP_CRATE_01 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_01.gltf"
const PROP_CRATE_06 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_06.gltf"
const PROP_LANTERN := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Lantern_01.gltf"
const PROP_LANTERN_2 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Lantern_02.gltf"
const PROP_NOODLE_BOX := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Noodle_Box_01.gltf"
const PROP_WIRES := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Wires_05.gltf"
const PROP_HOLO_SIGN := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Holo_Sign_03.gltf"
const PROP_TRASH_BIN := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Trash_Bin_03.gltf"
const VEH_CART := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Vehicles/SM_Veh_Cart_01.gltf"
const ENV_CHERRY := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Environment/SM_Env_Hologram_Cherry_Tree_02.gltf"
# Samurai Empire (the old district under the neon)
const SM_TORII := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Prop_Torii_Gate_01.gltf"
const SM_TORII_2 := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Prop_Torii_Gate_02.gltf"
const SM_SHRINE := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Bld_Shrine_02.gltf"
const SM_SHRINE_SMALL := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Prop_Shrine_01.gltf"
const SM_STAND := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Prop_Market_Stand_01.gltf"
const SM_LANTERN := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Prop_Lantern_03.gltf"
const SM_BANNER := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Prop_Banner_03.gltf"
const SM_BANNER_2 := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Prop_Banner_06.gltf"
const SM_UMBRELLA := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Prop_Umbrella_01.gltf"
const SM_BARREL := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Prop_Barrel_01.gltf"
const SM_STATUE := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Prop_Statue_02.gltf"
const SM_BONSAI := "res://assets/meshes/POLYGON_Samurai_SourceFiles_v2/SourceFiles/FBX/SM_Prop_Bonsai_01.gltf"

const ROOF_H := 3.4
const DECK_T := 0.3
const RAMP_TILT := 26.57

const NINJATO := "res://resources/gear/ninjato.tres"
const SHURIKEN := "res://resources/gear/shuriken.tres"
const KATANA := "res://resources/gear/katana.tres"

func site_id() -> String:
	return "littlejapan"

func site_name() -> String:
	return "LITTLE JAPAN"

func arena_half() -> float:
	return 30.0

func ground_color() -> Color:
	return Color(0.15, 0.13, 0.14)  # wet market flagstone, neon-stained

func sun_energy() -> float:
	return 0.6

func fog_density() -> float:
	return 0.005  # steam off the stalls hanging in the neon

func sky_energy() -> float:
	return 0.8  # open street, but the awnings and wires eat some of it

func wall_color() -> Color:
	return Color(0.16, 0.13, 0.14)

func ambient() -> String:
	return "ambient_market"

func floor_heights() -> Array:
	return [0.0, ROOF_H]  # street level and the shop roofs

func ground_params() -> Dictionary:
	# Small wet market cobbles: tight slabs, water everywhere from the stalls
	# and the steam, every joint black with grime. The neon lives in it.
	return {"tile_size": 1.5, "grout_width": 0.055, "tile_variation": 0.18,
		"grime_amount": 0.75, "grime_scale": 0.35, "crack_amount": 0.3,
		"base_color": Color(0.24, 0.20, 0.22),
		"wet_amount": 0.95, "puddle_scale": 0.16,
		"base_roughness": 0.6, "wet_roughness": 0.04, "metallic_amount": 0.05}

func gates() -> Array:
	return [{"side": "e", "center": 12.0}]  # the arcade back to the street

## Neon everywhere: magenta and cyan over the stalls, a warm shrine glow.
func flood_lights() -> Array:
	return [
		[Vector3(-16, 6, 14), Color(0.95, 0.25, 0.65), 2.2],
		[Vector3(16, 6, 10), Color(0.2, 0.85, 1.0), 2.2],
		[Vector3(-14, 6, -12), Color(1.0, 0.55, 0.25), 1.8],
		[Vector3(12, 6, -16), Color(0.7, 0.3, 1.0), 1.8],
		[Vector3(0, 7, 0), Color(0.9, 0.4, 0.7), 1.6],
	]

## The market street: stalls, carts, barrels and vending run down both sides
## of a central alley — dense cover, tight sightlines, ambush country.
func cover_layout() -> Array:
	return [
		# West stall row.
		[SM_STAND, -12.0, 16.0, 90.0], [SM_STAND, -12.0, 8.0, 90.0],
		[SM_STAND, -12.0, 0.0, 90.0], [SM_STAND, -12.0, -8.0, 90.0],
		[SM_BARREL, -8.5, 12.0, 0.0], [SM_BARREL, -9.0, 4.0, 20.0],
		[PROP_VENDING, -8.0, -4.0, 90.0], [SM_BARREL, -8.5, -12.0, 40.0],
		# East stall row.
		[SM_STAND, 12.0, 14.0, 270.0], [SM_STAND, 12.0, 6.0, 270.0],
		[SM_STAND, 12.0, -2.0, 270.0], [SM_STAND, 12.0, -10.0, 270.0],
		[PROP_VENDING, 8.0, 10.0, 270.0], [PROP_VENDING, 9.4, 10.0, 270.0],
		[SM_BARREL, 8.5, 2.0, 0.0], [PROP_CRATE_01, 8.0, -6.0, 25.0],
		# The alley's own clutter — you fight THROUGH this, never across it.
		[PROP_CRATE_06, -3.0, 6.0, 15.0], [PROP_CRATE_01, 3.0, -1.0, 60.0],
		[SM_BARREL, 2.0, 12.0, 0.0], [PROP_CRATE_06, -2.0, -10.0, 35.0],
		[SM_STATUE, -4.5, -18.0, 20.0], [SM_STATUE, 4.5, -18.0, -20.0],
		# South end: the gang's shakedown corner.
		[PROP_CRATE_01, -10.0, 22.0, 10.0], [PROP_CRATE_06, 9.0, 22.0, 50.0],
		# Roof cover for the watch (5th element = floor height).
		[PROP_CRATE_01, -14.0, 6.0, 0.0, ROOF_H],
		[PROP_CRATE_06, 14.0, 2.0, 30.0, ROOF_H],
		[SM_BARREL, -14.0, -6.0, 0.0, ROOF_H],
	]

func crew_spawns() -> Array:
	return [
		Vector3(24.0, 0.1, 13.0), Vector3(25.5, 0.1, 11.0),
		Vector3(24.0, 0.1, 9.5), Vector3(26.5, 0.1, 12.5),
	]

func enemy_spawns() -> Array:
	return [
		# ── The market crowd: unarmed, and they RUN when it starts ──────────
		{"skin": "geisha", "pos": Vector3(-6.0, 0.1, 10.0), "pack": "crowd",
			"faction": Factions.CIVIL, "required": false, "unarmed": true,
			"hp": 25.0, "xp": 0,
			"morale": true, "morale_frac": 0.99, "pursue": false, "aggro": 0.0,
			"patrol": [Vector3(-6.0, 0.1, 16.0), Vector3(-2.0, 0.1, 4.0)]},
		{"skin": "villager_f", "pos": Vector3(4.0, 0.1, 14.0), "pack": "crowd",
			"faction": Factions.CIVIL, "required": false, "unarmed": true,
			"hp": 25.0, "xp": 0,
			"morale": true, "morale_frac": 0.99, "pursue": false, "aggro": 0.0,
			"patrol": [Vector3(6.0, 0.1, 18.0), Vector3(-4.0, 0.1, 12.0)]},
		{"skin": "villager_m", "pos": Vector3(-3.0, 0.1, -2.0), "pack": "crowd",
			"faction": Factions.CIVIL, "required": false, "unarmed": true,
			"hp": 25.0, "xp": 0,
			"morale": true, "morale_frac": 0.99, "pursue": false, "aggro": 0.0,
			"patrol": [Vector3(-8.0, 0.1, -4.0), Vector3(4.0, 0.1, 2.0)]},
		{"skin": "villager_m2", "pos": Vector3(6.0, 0.1, -8.0), "pack": "crowd",
			"faction": Factions.CIVIL, "required": false, "unarmed": true,
			"hp": 25.0, "xp": 0,
			"morale": true, "morale_frac": 0.99, "pursue": false, "aggro": 0.0,
			"patrol": [Vector3(8.0, 0.1, -14.0), Vector3(2.0, 0.1, -2.0)]},
		{"skin": "geisha", "pos": Vector3(-9.0, 0.1, 20.0), "pack": "crowd",
			"faction": Factions.CIVIL, "required": false, "unarmed": true,
			"hp": 25.0, "xp": 0,
			"morale": true, "morale_frac": 0.99, "pursue": false, "aggro": 0.0},

		# ── The clan patrol: silent steel, and they vanish when hurt ─────────
		{"skin": "cyber_ninja", "pos": Vector3(-4.0, 0.1, 4.0), "pack": "patrol",
			"faction": Factions.CLAN, "required": false, "vanisher": true,
			"hp": 85.0, "xp": 30, "aggro": 14.0, "pursue": true, "gear": NINJATO,
			"patrol": [Vector3(-6.0, 0.1, 14.0), Vector3(-4.0, 0.1, -10.0)]},
		{"skin": "cyber_ninja", "pos": Vector3(5.0, 0.1, 6.0), "pack": "patrol",
			"faction": Factions.CLAN, "required": false, "vanisher": true,
			"hp": 85.0, "xp": 30, "aggro": 14.0, "pursue": true, "gear": SHURIKEN,
			"patrol": [Vector3(6.0, 0.1, 16.0), Vector3(4.0, 0.1, -6.0)]},
		{"skin": "ninja", "pos": Vector3(0.0, 0.1, -12.0), "pack": "patrol",
			"faction": Factions.CLAN, "required": false, "vanisher": true,
			"hp": 85.0, "xp": 30, "aggro": 14.0, "pursue": true, "gear": NINJATO},

		# ── The rooftop watch: silent shuriken from above ────────────────────
		{"skin": "ninja", "pos": Vector3(-14.0, 3.55, 10.0), "pack": "roof",
			"faction": Factions.CLAN, "required": false, "vanisher": true,
			"hp": 70.0, "xp": 30, "aggro": 20.0, "pursue": false, "gear": SHURIKEN,
			"patrol": [Vector3(-14.0, ROOF_H, 16.0), Vector3(-14.0, ROOF_H, -8.0)]},
		{"skin": "ninja", "pos": Vector3(14.0, 3.55, 4.0), "pack": "roof",
			"faction": Factions.CLAN, "required": false, "vanisher": true,
			"hp": 70.0, "xp": 30, "aggro": 20.0, "pursue": false, "gear": SHURIKEN,
			"patrol": [Vector3(14.0, ROOF_H, 14.0), Vector3(14.0, ROOF_H, -10.0)]},

		# ── The sensei at the shrine: the clan's authority, deep HP ──────────
		{"skin": "sensei", "pos": Vector3(0.0, 0.1, -22.0), "pack": "shrine",
			"faction": Factions.CLAN, "required": false, "vanisher": true,
			"hp": 260.0, "xp": 90, "aggro": 16.0, "pursue": false, "gear": KATANA},
		{"skin": "clan_warrior", "pos": Vector3(-4.0, 0.1, -20.0), "pack": "shrine",
			"faction": Factions.CLAN, "required": false, "hp": 110.0, "xp": 35,
			"aggro": 15.0, "pursue": false, "gear": KATANA},
		{"skin": "clan_warrior", "pos": Vector3(4.0, 0.1, -20.0), "pack": "shrine",
			"faction": Factions.CLAN, "required": false, "hp": 110.0, "xp": 35,
			"aggro": 15.0, "pursue": false, "gear": NINJATO},

		# ── The gang incursion: shaking down the south stalls. The clan is
		#    ALREADY at war with them — walk in and the fight is on without
		#    you (or start yours while they are busy).
		{"skin": "biker", "pos": Vector3(-8.0, 0.1, 21.0), "pack": "shakedown",
			"morale": true, "xp": 12, "gear": "res://resources/gear/enemy_rifle.tres"},
		{"skin": "punk", "pos": Vector3(-4.0, 0.1, 23.0), "pack": "shakedown",
			"morale": true, "xp": 12},
		{"skin": "gangster", "pos": Vector3(6.0, 0.1, 22.0), "pack": "shakedown",
			"morale": true, "xp": 12, "gear": "res://resources/gear/enemy_pistol.tres"},
		{"skin": "punk_girl", "pos": Vector3(9.0, 0.1, 20.0), "pack": "shakedown",
			"morale": true, "xp": 12, "gear": "res://resources/gear/scrap_blade.tres"},
	]

func build_extra_geometry() -> void:
	_build_roofs()
	_build_shrine()
	_build_market_dressing()
	_build_neon()

## Shop roofs down both sides — the watch's ground. Ramps at the south end
## (crates stacked against the awnings, in fiction) let anyone up.
func _build_roofs() -> void:
	var deck_y := ROOF_H - DECK_T * 0.5
	add_walkable_box(Vector3(-14.0, deck_y, 2.0), Vector3(7.0, DECK_T, 40.0),
		0.0, 0.0, Color(0.22, 0.17, 0.18), 0.03)
	add_walkable_box(Vector3(14.0, deck_y, 0.0), Vector3(7.0, DECK_T, 40.0),
		0.0, 0.0, Color(0.22, 0.17, 0.18), 0.03)
	# Ramps up from the market's south end.
	add_walkable_box(Vector3(-14.0, ROOF_H * 0.5 - 0.15, 25.0),
		Vector3(3.5, DECK_T, 7.6), RAMP_TILT, 0.0, Color(0.22, 0.17, 0.18), 0.03)
	add_walkable_box(Vector3(14.0, ROOF_H * 0.5 - 0.15, 23.0),
		Vector3(3.5, DECK_T, 7.6), RAMP_TILT, 0.0, Color(0.22, 0.17, 0.18), 0.03)
	# Roof-edge rails so the drop reads (visual only, as everywhere).
	add_rail(Vector3(-10.6, ROOF_H + 0.35, 2.0), Vector3(0.08, 0.7, 40.0),
		Color(0.85, 0.2, 0.35), 0.5)
	add_rail(Vector3(10.6, ROOF_H + 0.35, 0.0), Vector3(0.08, 0.7, 40.0),
		Color(0.85, 0.2, 0.35), 0.5)

## The shrine at the north end: torii approach, the shrine itself, statues,
## lanterns, and the sensei's ground.
func _build_shrine() -> void:
	add_decor(SM_TORII, Vector3(0.0, 0, -14.0), 0.0, 1.15)
	add_decor(SM_TORII_2, Vector3(0.0, 0, -6.0), 0.0, 0.95)
	add_decor(SM_SHRINE, Vector3(0.0, 0, -25.0), 0.0, 1.1)
	add_decor(SM_SHRINE_SMALL, Vector3(-7.0, 0, -24.0), 25.0)
	add_decor(SM_SHRINE_SMALL, Vector3(7.0, 0, -24.0), -25.0)
	add_decor(SM_BONSAI, Vector3(-9.5, 0, -19.0), 0.0)
	add_decor(SM_BONSAI, Vector3(9.5, 0, -19.0), 0.0)
	for z in [-24.0, -20.0, -16.0]:
		for x in [-3.2, 3.2]:
			add_decor(SM_LANTERN, Vector3(x, 0, z), 0.0)
			add_practical_light(Vector3(x, 1.5, z), Color(1.0, 0.62, 0.28), 1.1, 5.0)
	add_practical_light(Vector3(0, 3.0, -25.0), Color(1.0, 0.55, 0.3), 2.0, 10.0)
	add_neon_sign("神社", Vector3(0.0, 4.6, -26.5), Color(1.0, 0.45, 0.3), 0.0, 80)

## The market itself: awning banners, hanging lanterns, food cartons, wires
## across the alley, a hologram cherry tree at the crossroads.
func _build_market_dressing() -> void:
	for z in [18.0, 10.0, 2.0, -6.0]:
		add_decor(SM_BANNER, Vector3(-10.2, 0, z), 90.0)
		add_decor(SM_BANNER_2, Vector3(10.2, 0, z - 2.0), 270.0)
	for z in [16.0, 8.0, 0.0, -8.0]:
		add_decor(PROP_LANTERN, Vector3(-7.5, 2.9, z), 0.0)
		add_decor(PROP_LANTERN_2, Vector3(7.5, 2.9, z + 3.0), 0.0)
		add_practical_light(Vector3(-7.5, 2.6, z), Color(1.0, 0.35, 0.45), 1.3, 6.0)
		add_practical_light(Vector3(7.5, 2.6, z + 3.0), Color(0.35, 0.85, 1.0), 1.3, 6.0)
	for z in [14.0, 4.0, -6.0, -16.0]:
		add_decor(PROP_WIRES, Vector3(0.0, 3.3, z), 90.0)
	add_decor(ENV_CHERRY, Vector3(-2.5, 0, 8.0), 0.0)
	add_practical_light(Vector3(-2.5, 2.8, 8.0), Color(1.0, 0.45, 0.7), 1.5, 8.0)
	add_decor(VEH_CART, Vector3(6.5, 0, 17.0), 200.0)
	add_decor(VEH_CART, Vector3(-6.0, 0, -1.0), 15.0)
	add_decor(SM_UMBRELLA, Vector3(-9.0, 0, 6.0), 0.0)
	add_decor(SM_UMBRELLA, Vector3(9.2, 0, -4.0), 0.0)
	add_decor(PROP_NOODLE_BOX, Vector3(-11.2, 1.0, 8.4), 30.0)
	add_decor(PROP_NOODLE_BOX, Vector3(11.4, 1.0, 6.2), 200.0)
	add_decor(PROP_TRASH_BIN, Vector3(-9.5, 0, 22.0), 40.0)
	add_decor(PROP_HOLO_SIGN, Vector3(9.0, 0, 14.0), 250.0)
	add_steam(Vector3(-11.0, 0, 16.0))
	add_steam(Vector3(11.0, 0, 6.0))
	add_steam(Vector3(-3.0, 0, -4.0))

## The signage — this is the loudest street in the district.
func _build_neon() -> void:
	add_neon_sign("リトル ジャパン", Vector3(0.0, 4.2, 28.6), Color(1.0, 0.3, 0.55),
		180.0, 90, true)
	add_neon_sign("麺", Vector3(-10.4, 3.1, 16.0), Color(1.0, 0.55, 0.2), 90.0, 90, true)
	add_neon_sign("酒", Vector3(10.4, 3.1, 8.0), Color(0.35, 0.9, 1.0), 270.0, 90, true)
	add_neon_sign("刀", Vector3(-10.4, 3.1, -2.0), Color(0.95, 0.25, 0.45), 90.0, 90)
	add_neon_sign("薬", Vector3(10.4, 3.1, -10.0), Color(0.7, 0.35, 1.0), 270.0, 80, true)
	add_practical_light(Vector3(-9.6, 3.1, 16.0), Color(1.0, 0.55, 0.2), 1.6, 6.0, true)
	add_practical_light(Vector3(9.6, 3.1, 8.0), Color(0.35, 0.9, 1.0), 1.6, 6.0, true)
	add_practical_light(Vector3(9.6, 3.1, -10.0), Color(0.7, 0.35, 1.0), 1.4, 6.0, true)
