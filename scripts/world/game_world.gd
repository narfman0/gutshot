@tool
## The district root — ONE seamless world (docs/architecture.md).
##
## Scene contract: GameWorld → Environment / Sun / Level / Squad / EnemySquad
## / ObjectiveManager / CameraRig / HUD. $Level holds scene INSTANCES of the
## site chunks (scenes/sites/*.tscn), positioned by their editor transforms;
## GameWorld builds connector corridors between paired gates, bakes one
## navmesh over everything, spawns the crew once at the start site, spawns
## (and respawns) every site's packs, and tracks which site the crew is in —
## site entry drives the HUD label, autosave, the hideout rest, and the
## light/air mood lerp. There are no scene loads inside a run: travel is on
## foot through the corridors.
##
## @tool: opening scenes/district.tscn in the editor previews the whole
## assembled district (chunks self-build; this script adds the connectors).
## Everything else is runtime-only.
class_name GameWorld
extends Node3D

# ── Camera (wayfarer framing, pulled back further for the tactical read) ─────
const _ISO_YAW := deg_to_rad(45.0)
const _ISO_PITCH := deg_to_rad(-30.0)
const _ISO_DIST := 40.0
const _ZOOM_MIN := 11.0
const _ZOOM_MAX := 24.0
const _ZOOM_STEP := 2.0
const _CAM_FOLLOW_SPEED := 8.0
var _zoom := 17.0  # close enough that sprinting reads fast; wheel adjusts

const CharacterScene := preload("res://scenes/characters/character.tscn")

## Connector graph: [site_id_a, gate_index_a, site_id_b, gate_index_b, style].
## Gate positions come from the chunks' transforms + gate specs, so moving a
## site instance in the editor moves its corridors with it (on rebuild).
const CONNECTORS := [
	["hideout", 0, "skirmish", 0, "alley"],
	["skirmish", 1, "exchange", 0, "arcade"],
	["exchange", 1, "depot", 0, "service"],
	["depot", 1, "fab", 0, "tunnel"],
	["skirmish", 2, "tower", 0, "plaza"],
	["skirmish", 3, "littlejapan", 0, "market"],
]

# Corridor dressing props — full res:// literals for fetch_assets.sh's scan.
const _CRATE_01 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_01.gltf"
const _CRATE_04 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_04.gltf"
const _CRATE_06 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Crate_06.gltf"
const _VENDING := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Vending_Machine_01.gltf"
const _EBOX := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Electrical_Box_01.gltf"
const _SHELF := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Props/SM_Prop_Shelf_01.gltf"
const _CONTAINER_SMALL := "res://assets/meshes/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Prop_Shipping_Container_Small_01.gltf"
# Corridors run BETWEEN buildings — these line their flanks so an alley
# reads as a gap in the city rather than a trench in the ground.
const _BLD_SMALL_01 := "res://assets/meshes/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Background_Small_01.gltf"
const _BLD_SMALL_02 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_02.gltf"
const _BLD_SMALL_04 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_04.gltf"
const _BLD_MED_02 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_02.gltf"
const _BLD_MED_07 := "res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_04.gltf"
const _BLD_INDUSTRIAL := "res://assets/meshes/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Industrial_02.gltf"
const _BLD_ADVANCED := "res://assets/meshes/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Advanced_02.gltf"
const _BLD_DOBEI := "res://assets/meshes/POLYGON_Samurai_Empire_SourceFiles_v1/SourceFiles/FBX/SamuraiEmpire/SM_Bld_Fence_Dobei_Double_01.gltf"

## Each corridor has an identity: wall/floor tone, light colors (pools
## alternate through the list), edge-strip glow, junk along the walls, and
## whether overhead beams span it. Props are real cover — corridor fights
## have something to duck behind.
const CORRIDOR_STYLES := {
	"alley": {  # hideout ↔ street: the crew's grimy back way, sodium-lit
		"wall": Color(0.15, 0.14, 0.13), "floor": Color(0.12, 0.12, 0.13),
		"lights": [Color(1.0, 0.6, 0.25)], "strip": Color(1.0, 0.7, 0.3),
		"props": [_CRATE_06, _CRATE_01, _VENDING, _CRATE_04], "beams": false,
		"flank": [_BLD_SMALL_02, _BLD_SMALL_04],
		"ground": {"tile_size": 2.6, "grout_width": 0.04, "grime_amount": 0.85,
			"grime_scale": 0.3, "crack_amount": 0.5, "wet_amount": 0.7,
			"puddle_scale": 0.2, "base_roughness": 0.7},
	},
	"arcade": {  # street ↔ exchange: dead shopfronts, neon still buzzing
		"wall": Color(0.15, 0.16, 0.19), "floor": Color(0.16, 0.16, 0.18),
		"lights": [Color(0.2, 0.8, 1.0), Color(0.95, 0.3, 0.75)],
		"strip": Color(0.2, 0.8, 1.0),
		"props": [_VENDING, _CRATE_01, _VENDING, _SHELF], "beams": true,
		"flank": [_BLD_MED_02, _BLD_SMALL_01, _BLD_MED_07],
		"ground": {"tile_size": 1.8, "grout_width": 0.05, "grime_amount": 0.6,
			"grime_scale": 0.4, "wet_amount": 0.5, "base_roughness": 0.5,
			"metallic_amount": 0.1},
	},
	"service": {  # exchange ↔ depot: maintenance passage behind the hall
		"wall": Color(0.18, 0.18, 0.17), "floor": Color(0.15, 0.15, 0.14),
		"lights": [Color(1.0, 0.65, 0.25)], "strip": Color(1.0, 0.65, 0.3),
		"props": [_EBOX, _CRATE_04, _EBOX, _SHELF], "beams": false,
		"flank": [_BLD_INDUSTRIAL, _BLD_MED_07],
		"ground": {"tile_size": 10.0, "grout_width": 0.01, "grime_amount": 0.8,
			"grime_scale": 0.09, "crack_amount": 0.45, "base_roughness": 0.85},
	},
	"tunnel": {  # depot ↔ fab: the freight tunnel, cold and echoing
		"wall": Color(0.14, 0.15, 0.17), "floor": Color(0.13, 0.14, 0.16),
		"lights": [Color(0.35, 0.6, 1.0)], "strip": Color(0.4, 0.7, 1.0),
		"props": [_CONTAINER_SMALL, _CRATE_01, _EBOX], "beams": true,
		"flank": [_BLD_INDUSTRIAL],
		"ground": {"tile_size": 4.0, "grout_width": 0.02, "grime_amount": 0.5,
			"grime_scale": 0.15, "wet_amount": 0.35, "puddle_scale": 0.22,
			"base_roughness": 0.7, "metallic_amount": 0.25},
	},
	"plaza": {  # street ↔ tower: the corporate approach — swept, lit, watched
		"wall": Color(0.42, 0.44, 0.45), "floor": Color(0.36, 0.38, 0.38),
		"lights": [Color(0.85, 0.92, 1.0)], "strip": Color(0.7, 0.9, 1.0),
		"props": [], "beams": false,
		"flank": [_BLD_ADVANCED, _BLD_MED_02],
		"ground": {"tile_size": 3.0, "grout_width": 0.008, "grime_amount": 0.06,
			"base_roughness": 0.16, "metallic_amount": 0.15},
	},
	"market": {  # street ↔ Little Japan: paper lanterns and knock-off neon
		"wall": Color(0.17, 0.13, 0.15), "floor": Color(0.14, 0.12, 0.13),
		"lights": [Color(1.0, 0.35, 0.45), Color(1.0, 0.62, 0.25)],
		"strip": Color(1.0, 0.4, 0.5),
		"props": [_CRATE_06, _VENDING, _CRATE_01], "beams": true,
		"flank": [_BLD_DOBEI, _BLD_SMALL_01],
		"ground": {"tile_size": 1.4, "grout_width": 0.06, "grime_amount": 0.8,
			"grime_scale": 0.36, "wet_amount": 0.9, "puddle_scale": 0.18,
			"base_roughness": 0.6, "wet_roughness": 0.04},
	},
}

## Seconds a cleared site must sit vacated before its packs repopulate.
## Harnesses shrink this to test the respawn cycle quickly.
var respawn_delay := 5.0

@onready var _level: Node3D = $Level
@onready var _squad: Squad = $Squad
@onready var _enemy_squad: Node3D = $EnemySquad
@onready var _objectives: ObjectiveManager = $ObjectiveManager
@onready var _cam_pivot: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D

var _game_over := false
var _nav_regions := {}       # site_id / "corridor_N" -> region RID
var _rebake_sites := {}      # site_id -> true while a rebake is queued/running
var _corridor_aabbs: Array = []

var _chunks: Array = []          # every SiteChunk under $Level
var _chunks_by_id := {}          # site_id -> SiteChunk
var _active_site := ""           # site the ACTIVE character is in (sticky in corridors)
var _site_state := {}            # site_id -> {vacant: float, records: Array}
var _mood_tween: Tween = null

func _ready() -> void:
	_collect_chunks()
	if Engine.is_editor_hint():
		_build_connectors()
		_build_backdrop()
		return
	add_to_group("nav_owner")
	for chunk in _chunks:
		chunk.world = self
	_setup_environment()
	_build_connectors()
	_build_backdrop()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_bake_district()
	_spawn_crew()
	_spawn_all_enemies()
	_setup_camera()
	($HUD as Hud).setup(_squad, _objectives, _camera, _start_chunk().site_name())
	_objectives.mission_failed.connect(_show_wipe_screen)
	_objectives.site_cleared.connect(_on_site_cleared)
	GameState.crew_leveled.connect(_on_crew_leveled)
	refresh_job()  # a Continue mid-contract rebuilds the objective
	_tick_sites(0.0)  # register the arrival site (label, save, mood, ambient)
	SceneManager.fade_in()

func _collect_chunks() -> void:
	_chunks = []
	_chunks_by_id = {}
	for child in get_node("Level").get_children():
		if child is SiteChunk:
			_chunks.append(child)
			_chunks_by_id[(child as SiteChunk).site_id()] = child
			_site_state[(child as SiteChunk).site_id()] = {"vacant": 0.0, "records": []}

func _start_chunk() -> SiteChunk:
	return _chunks_by_id.get(GameState.start_site, _chunks_by_id.get("hideout", _chunks[0]))

func active_character() -> Character:
	return _squad.active_character()

func active_site_id() -> String:
	return _active_site

## One navmesh REGION per site and per corridor, each baked only inside its
## AABB (a single district-wide bake takes minutes; these take a blink).
## Adjacent regions stitch through the map's edge-connection margin: a site's
## bake and its corridor's bake both clip at the gate's wall plane, leaving
## boundary edges close enough to connect.
func _bake_district() -> void:
	NavigationServer3D.map_set_edge_connection_margin(
		get_world_3d().navigation_map, 1.0)
	var bake_start := Time.get_ticks_msec()
	for chunk in _chunks:
		_nav_regions[chunk.site_id()] = NavRuntime.bake(
			self, Layers.GROUND | Layers.COVER, 0.4, _chunk_aabb(chunk))
	for i in _corridor_aabbs.size():
		_nav_regions["corridor_%d" % i] = NavRuntime.bake(
			self, Layers.GROUND | Layers.COVER, 0.4, _corridor_aabbs[i])
	print("district navmesh: %d regions baked in %d ms"
		% [_nav_regions.size(), Time.get_ticks_msec() - bake_start])

func _chunk_aabb(chunk: SiteChunk) -> AABB:
	var r := chunk.bounds_rect()
	return AABB(Vector3(r.position.x, -1.0, r.position.y),
		Vector3(r.size.x, 12.0, r.size.y))

## Re-bake after geometry changes (a breached door opening a path) — only
## the site containing the change, threaded so the fight never hitches; the
## old mesh stays live until the swap. Deferred + debounced per site.
func rebake_nav(at := Vector3.INF) -> void:
	var ids: Array = []
	if at != Vector3.INF:
		for chunk in _chunks:
			if (chunk as SiteChunk).bounds_rect().grow(2.0).has_point(Vector2(at.x, at.z)):
				ids.append(chunk.site_id())
				break
	if ids.is_empty():
		ids = _chunks.map(func(c): return c.site_id())  # unknown source: all sites
	for id in ids:
		if _rebake_sites.has(id):
			continue
		_rebake_sites[id] = true
		_do_rebake.call_deferred(id)

func _do_rebake(id: String) -> void:
	# Wait a physics frame so queue_free'd geometry (breached doors) is
	# actually gone before the parser walks the world.
	await get_tree().physics_frame
	_rebake_sites.erase(id)
	var chunk: SiteChunk = _chunks_by_id[id]
	var new_rid: RID = await NavRuntime.bake_async(
		self, Layers.GROUND | Layers.COVER, 0.4, _chunk_aabb(chunk))
	# Overlap-first swap: the new region must SYNC into the map before the
	# old one goes — a one-frame region gap lets the prop-top unstick guard
	# see "nearest navmesh = the floor below" and yank everyone standing on
	# a deck down eight metres.
	var old: RID = _nav_regions.get(id, RID())
	_nav_regions[id] = new_rid
	await get_tree().physics_frame
	await get_tree().physics_frame
	if old.is_valid():
		NavigationServer3D.free_rid(old)

# ── Environment (one sky, per-site mood lerped on entry) ─────────────────────

## The hive city's night sky: a code-driven ProceduralSkyMaterial rather
## than a panorama — deep violet at the zenith, the city's own light
## pollution smeared along the horizon (sodium orange bleeding into the
## neon magenta the district actually runs on). No sun disk: the sun is a
## dim moonlight fill, and a hard disk at -55° would read as daytime.
func _make_sky() -> Sky:
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.035, 0.028, 0.065)
	mat.sky_horizon_color = Color(0.19, 0.11, 0.16)
	mat.sky_curve = 0.12          # tight glow band — pollution hugs the skyline
	mat.sky_energy_multiplier = 1.0
	mat.ground_bottom_color = Color(0.012, 0.012, 0.018)
	mat.ground_horizon_color = Color(0.10, 0.07, 0.09)
	mat.ground_curve = 0.05
	mat.sun_angle_max = 1.0
	mat.sun_curve = 0.02
	var sky := Sky.new()
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky

func _setup_environment() -> void:
	var start := _start_chunk()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = _make_sky()
	# Interiors are open-topped boxes — background energy IS their ceiling.
	env.background_energy_multiplier = start.sky_energy()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.75)
	env.ambient_light_energy = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	# Screen-space reflections: the whole point of wet ground. Neon, muzzle
	# flashes and sign glow land in the puddles the ground shader carves.
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 8.0
	env.ssr_depth_tolerance = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	# Fog is always on; density lerps toward the active site's air.
	env.fog_enabled = true
	env.fog_density = start.fog_density()
	env.fog_light_color = Color(0.05, 0.06, 0.08)
	env.fog_sky_affect = 0.0
	($Environment as WorldEnvironment).environment = env
	var sun := $Sun as DirectionalLight3D
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0.0)
	sun.light_color = Color(0.85, 0.88, 1.0)
	sun.light_energy = start.sun_energy()
	sun.shadow_enabled = true
	# Light only — a sun disk in the sky would call it daytime.
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY

## Crossing into a site retunes the world's air: fog density and sun energy
## ease toward the site's mood over a couple of seconds.
func _apply_mood(chunk: SiteChunk) -> void:
	var env := ($Environment as WorldEnvironment).environment
	if _mood_tween != null and _mood_tween.is_valid():
		_mood_tween.kill()
	_mood_tween = create_tween().set_parallel()
	_mood_tween.tween_property(env, "fog_density", chunk.fog_density(), 1.8)
	_mood_tween.tween_property($Sun, "light_energy", chunk.sun_energy(), 1.8)
	_mood_tween.tween_property(env, "background_energy_multiplier",
		chunk.sky_energy(), 1.8)

# ── Connectors (walled corridors between gate pairs) ─────────────────────────

func _build_connectors() -> void:
	var stale := _level.get_node_or_null("GeneratedConnectors")
	if stale != null:
		stale.free()
	var root := Node3D.new()
	root.name = "GeneratedConnectors"
	_level.add_child(root)
	for i in CONNECTORS.size():
		var link: Array = CONNECTORS[i]
		var a: SiteChunk = _chunks_by_id.get(link[0])
		var b: SiteChunk = _chunks_by_id.get(link[2])
		if a == null or b == null:
			continue
		_build_corridor(root, a.gate_info(link[1]), b.gate_info(link[3]),
			CORRIDOR_STYLES[link[4]], a.site_name(), b.site_name(), i)

## A straight corridor between two gates: lit floor strip (into the navmesh),
## invisible barrier walls, edge glow so the path reads in the dark — plus
## the dressing that gives it an identity: visible walls (TALL on the
## camera-far side, a low curb on the camera-near side, so the iso camera is
## never blinded), junk-prop cover along the edges, overhead beams on the
## covered styles, per-style light pools, and destination signs at each end.
func _build_corridor(root: Node3D, ga: Dictionary, gb: Dictionary,
		style: Dictionary, name_a: String, name_b: String, index: int) -> void:
	var pa: Vector3 = ga["pos"] - ga["dir"] * 1.0  # tuck 1 m into each site —
	var pb: Vector3 = gb["pos"] - gb["dir"] * 1.0  # no navmesh crack at the wall
	var along: Vector3 = pb - pa
	var length := along.length()
	var axis := along.normalized()
	var cross := Vector3(-axis.z, 0, axis.x)
	var width: float = minf(ga["width"], gb["width"])
	var center := (pa + pb) * 0.5
	# Record the bake AABB: wall plane to wall plane along the corridor, so
	# the corridor's navmesh region meets each site's region at the gate.
	var lo := Vector3(minf(ga["pos"].x, gb["pos"].x), -1.0, minf(ga["pos"].z, gb["pos"].z))
	var hi := Vector3(maxf(ga["pos"].x, gb["pos"].x), 8.0, maxf(ga["pos"].z, gb["pos"].z))
	if absf(axis.x) > absf(axis.z):
		lo.z -= width * 0.5 + 1.5
		hi.z += width * 0.5 + 1.5
	else:
		lo.x -= width * 0.5 + 1.5
		hi.x += width * 0.5 + 1.5
	_corridor_aabbs.append(AABB(lo, hi - lo))
	# Floor slab (top at y = 0, same as site grounds).
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Layers.GROUND
	floor_body.add_to_group(NavRuntime.SOURCE_GROUP)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _axis_size(axis, length, 0.5, width)
	col.shape = box
	col.position.y = -0.25
	floor_body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = _axis_size(axis, length, 0.1, width)
	var floor_params: Dictionary = (style.get("ground", {}) as Dictionary).duplicate()
	floor_params["base_color"] = style["floor"]
	mesh.material = SiteChunk.make_ground_material(floor_params, style["floor"])
	mi.mesh = mesh
	mi.position.y = -0.04
	floor_body.add_child(mi)
	root.add_child(floor_body)
	floor_body.global_position = center
	# Barrier walls flanking the strip (invisible, full height) + visible
	# wall meshes: TALL on the camera-far side, a knee-high curb on the
	# camera-near side — a tall near wall would occlude the whole corridor
	# at the iso pitch. Camera sits toward +x/+z (yaw 45°, pitch -30°).
	for side in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		wall.collision_layer = Layers.BARRIERS
		var wcol := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = _axis_size(axis, length, SiteChunk.WALL_H, 1.0)
		wcol.shape = wbox
		wall.add_child(wcol)
		root.add_child(wall)
		wall.global_position = center + cross * side * (width * 0.5 + 0.5) \
			+ Vector3(0, SiteChunk.WALL_H * 0.5, 0)
		var camera_near: bool = (cross * side).dot(Vector3(1, 0, 1)) > 0.0
		var wall_h := 0.85 if camera_near else 3.4
		var wmesh_i := MeshInstance3D.new()
		var wmesh := BoxMesh.new()
		wmesh.size = _axis_size(axis, length + 1.0, wall_h, 0.5)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = style["wall"]
		wmat.roughness = 0.85
		wmesh.material = wmat
		wmesh_i.mesh = wmesh
		root.add_child(wmesh_i)
		wmesh_i.global_position = center + cross * side * (width * 0.5 + 0.5) \
			+ Vector3(0, wall_h * 0.5, 0)
	# Edge glow strips — the path reads even between the light pools.
	for side in [-1.0, 1.0]:
		var strip := MeshInstance3D.new()
		var smesh := BoxMesh.new()
		smesh.size = _axis_size(axis, length, 0.06, 0.12)
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.2, 0.5, 0.6)
		smat.emission_enabled = true
		smat.emission = style["strip"]
		smat.emission_energy_multiplier = 0.5
		smesh.material = smat
		strip.mesh = smesh
		root.add_child(strip)
		strip.global_position = center + cross * side * (width * 0.5 - 0.25) + Vector3(0, 0.03, 0)
	# Overhead beams on the covered styles — tunnel structure the iso camera
	# can live with (thin, high, no colliders).
	if style["beams"]:
		var beams := maxi(1, int(length / 8.0))
		for i in beams:
			var beam := MeshInstance3D.new()
			var bmesh := BoxMesh.new()
			bmesh.size = _axis_size(axis, 0.5, 0.35, width + 1.6)
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.10, 0.11, 0.13)
			bmat.metallic = 0.6
			bmat.roughness = 0.5
			bmesh.material = bmat
			beam.mesh = bmesh
			root.add_child(beam)
			beam.global_position = pa.lerp(pb, (float(i) + 0.5) / float(beams)) \
				+ Vector3(0, 3.3, 0)
	# Flanking buildings: the alley is a GAP between structures, not a
	# trench. Visual only (the barriers already contain the corridor), set
	# back so the walls — not the facades — define the walkable width.
	var flank: Array = style.get("flank", [])
	if not flank.is_empty():
		var bays := maxi(1, int(length / 15.0))
		for b in bays:
			var bt := (float(b) + 0.5) / float(bays)
			for fside in [-1.0, 1.0]:
				var fscene = load(flank[(b + int(fside > 0.0)) % flank.size()])
				if fscene == null:
					continue
				var bldg: Node3D = fscene.instantiate()
				var bsc := SiteChunk.cm_correction(bldg)
				bldg.scale = Vector3(bsc, bsc, bsc)
				root.add_child(bldg)
				bldg.global_position = pa.lerp(pb, bt) \
					+ cross * fside * (width * 0.5 + 9.0)
				bldg.rotation.y = atan2(-cross.x * fside, -cross.z * fside)
	# Light pools — per-style colors, alternating through the list.
	var colors: Array = style["lights"]
	var pools := maxi(1, int(length / 12.0))
	for i in pools:
		var t := (float(i) + 0.5) / float(pools)
		var light := OmniLight3D.new()
		light.light_color = colors[i % colors.size()]
		light.light_energy = 1.3
		light.omni_range = 8.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		root.add_child(light)
		light.global_position = pa.lerp(pb, t) + Vector3(0, 2.6, 0)
	# Junk along the walls — real cover, alternating sides, clear of the
	# gate mouths. Yaw is index-hashed so the editor preview is stable.
	# (The plaza keeps its props list empty — corporate approaches are swept.)
	var props: Array = style["props"]
	var slots := maxi(0, int((length - 8.0) / 7.0)) if not props.is_empty() else 0
	for j in slots:
		var t := (float(j) + 0.5) / float(slots)
		var side := -1.0 if j % 2 == 0 else 1.0
		var prop := StaticBody3D.new()
		prop.collision_layer = Layers.COVER
		prop.add_to_group("cover")
		prop.add_to_group(NavRuntime.SOURCE_GROUP)
		var visual: Node3D = null
		var scene = load(props[j % props.size()])
		if scene != null:
			visual = scene.instantiate()
			visual.scale.y = Character.VERTICAL_SQUASH
			prop.add_child(visual)
		root.add_child(prop)
		prop.global_position = pa.lerp(pb, t) + cross * side * (width * 0.5 - 1.0)
		prop.rotation.y = deg_to_rad(float((j * 67 + index * 131) % 360))
		SiteChunk.add_aabb_collider(prop, visual)
	# Destination signs just inside each mouth — wayfinding without a map.
	_corridor_sign(root, pa + axis * 2.2, "→ " + name_b, style)
	_corridor_sign(root, pb - axis * 2.2, "→ " + name_a, style)

func _corridor_sign(root: Node3D, pos: Vector3, text: String, style: Dictionary) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.outline_size = 8
	sign.modulate = (style["lights"][0] as Color).lightened(0.35)
	root.add_child(sign)
	sign.global_position = pos + Vector3(0, 2.3, 0)

# ── Backdrop: the hive city beyond the walls ─────────────────────────────────

const _BACKDROP_BLDGS := [
	"res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_01.gltf",
	"res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_02.gltf",
	"res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_03.gltf",
	"res://assets/meshes/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_04.gltf",
]

## The district no longer floats in void: a dark underlay plane fills the
## space between and beyond the sites, and a ring of background towers
## (Synty's purpose-built skyline silhouettes) stands beyond the walls.
## Visual-only — no colliders, no navmesh, no gameplay.
func _build_backdrop() -> void:
	var stale := _level.get_node_or_null("GeneratedBackdrop")
	if stale != null:
		stale.free()
	var root := Node3D.new()
	root.name = "GeneratedBackdrop"
	_level.add_child(root)
	if _chunks.is_empty():
		return
	var rect: Rect2 = (_chunks[0] as SiteChunk).bounds_rect()
	for chunk in _chunks:
		rect = rect.merge((chunk as SiteChunk).bounds_rect())
	# Underlay: the city floor under everything.
	var under := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(rect.size.x + 160.0, rect.size.y + 160.0)
	var umat := StandardMaterial3D.new()
	umat.albedo_color = Color(0.035, 0.04, 0.055)
	umat.roughness = 0.9
	plane.material = umat
	under.mesh = plane
	root.add_child(under)
	under.position = Vector3(rect.get_center().x, -0.2, rect.get_center().y)
	# Skyline ring ~28 m out from the district envelope, deterministic mix
	# of models/rotations so the editor preview is stable.
	# Close enough that tower tops loom over the walls at gameplay zoom.
	var ring := rect.grow(16.0)
	var perimeter := (ring.size.x + ring.size.y) * 2.0
	var count := int(perimeter / 34.0)
	for i in count:
		var t := float(i) / float(count) * perimeter
		var pos := _ring_point(ring, t)
		var h := (i * 2654435761) % 1000
		var scene = load(_BACKDROP_BLDGS[i % _BACKDROP_BLDGS.size()])
		if scene == null:
			continue
		var bldg: Node3D = scene.instantiate()
		# Buildings-tree glTFs are raw centimetres — cm_correction shrinks.
		var s := (0.7 + float(h % 400) / 1000.0) * SiteChunk.cm_correction(bldg)
		bldg.scale = Vector3(s, s * Character.VERTICAL_SQUASH, s)
		root.add_child(bldg)
		bldg.position = Vector3(pos.x, -0.2, pos.y)
		bldg.rotation.y = deg_to_rad(float(h % 4) * 90.0)

## Walk the rectangle's perimeter: distance t → point on the edge.
func _ring_point(ring: Rect2, t: float) -> Vector2:
	var w := ring.size.x
	var h := ring.size.y
	if t < w:
		return Vector2(ring.position.x + t, ring.position.y)
	t -= w
	if t < h:
		return Vector2(ring.end.x, ring.position.y + t)
	t -= h
	if t < w:
		return Vector2(ring.end.x - t, ring.end.y)
	t -= w
	return Vector2(ring.position.x, ring.end.y - t)

## Box size with `length` along the corridor axis and `width` across it.
func _axis_size(axis: Vector3, length: float, height: float, width: float) -> Vector3:
	if absf(axis.x) > absf(axis.z):
		return Vector3(length, height, width)
	return Vector3(width, height, length)

# ── Spawning ─────────────────────────────────────────────────────────────────

func _spawn_crew() -> void:
	if GameState.squad.is_empty() and not GameState.run_active:
		GameState.debug_session = true
	var start := _start_chunk()
	var smg: GearItem = load("res://resources/gear/smg.tres")
	var rifle: GearItem = load("res://resources/gear/rifle.tres")
	var pistol: GearItem = load("res://resources/gear/pistol.tres")
	var heal_gun: GearItem = load("res://resources/gear/heal_gun.tres")
	var belt: GearItem = load("res://resources/gear/grenade_belt.tres")
	var crew_keys: Array = Skins.crew_names()
	var members: Array = []
	for i in crew_keys.size():
		var key: String = crew_keys[i]
		var info: Dictionary = Skins.CREW[key]
		var c: Character = CharacterScene.instantiate()
		c.team = 0
		c.display_name = key.capitalize()
		c.anim_set = info["set"]
		# Crew stat curves: modest flat growth per crew level; the chunky
		# power comes from perk picks, not number inflation.
		c.max_hp = 100.0 + GameState.HP_PER_LEVEL * (GameState.crew_level - 1)
		c.max_shield = 40.0 + GameState.SHIELD_PER_LEVEL * (GameState.crew_level - 1)
		_squad.add_child(c)
		var spawns := start.crew_spawns()
		c.global_position = start.to_global(spawns[i % spawns.size()])
		c.setup_skin(info["path"])
		c.equip(rifle if key == "gunner" else smg)
		c.equip(heal_gun if key == "medic" else pistol)
		c.equip(belt)
		Talents.apply_all(c, key)
		# Crew condition carried from the save (the hideout rest heals anyway).
		var carried: Dictionary = GameState.crew_state.get(key, {})
		if not carried.is_empty():
			c.hp = clampf(float(carried.get("hp", c.max_hp)), 1.0, c.max_hp)
			c.shield = clampf(float(carried.get("shield", 0.0)), 0.0, c.max_shield)
		_squad.add_member(c)
		_objectives.register(c)
		members.append(c)
	GameState.set_squad(members)
	_squad.set_active(0)

func _spawn_all_enemies() -> void:
	for chunk in _chunks:
		var records: Array = []
		for entry in chunk.enemy_spawns():
			records.append({"entry": entry, "body": _spawn_enemy(chunk, entry)})
		_site_state[chunk.site_id()]["records"] = records

func _spawn_enemy(chunk: SiteChunk, entry: Dictionary, generation := 0) -> Character:
	var smg: GearItem = load("res://resources/gear/enemy_smg.tres")
	var belt: GearItem = load("res://resources/gear/grenade_belt.tres")
	var all_skins := {}
	all_skins.merge(Skins.ENEMIES)
	all_skins.merge(Skins.MACHINES)
	all_skins.merge(Skins.CORP)
	all_skins.merge(Skins.HORDE)
	all_skins.merge(Skins.CLAN)
	all_skins.merge(Skins.CIVILIANS)
	var info: Dictionary = all_skins[entry["skin"]]
	var c: Character = CharacterScene.instantiate()
	c.team = entry.get("faction", Factions.GANGS)
	c.display_name = String(entry["skin"]).capitalize()
	c.anim_set = info["set"]
	c.max_hp = entry.get("hp", 60.0)  # swarm trash runs lean, brutes deep
	c.max_shield = entry.get("shield", 0.0)  # corp guards get the layer
	_enemy_squad.add_child(c)
	c.global_position = chunk.to_global(entry["pos"])
	c.setup_skin(info["path"])
	# Civilians carry nothing — no gun, no belt. An unarmed body can never
	# fire, so the whole combat path simply never engages for them.
	if not entry.get("unarmed", false):
		c.equip(smg)
		c.equip(belt)  # dug-in crew get cover-called too
	var brain := CombatBrain.new()
	brain.name = "CombatBrain"
	c.add_child(brain)
	var controller := EnemyController.new()
	controller.name = "EnemyController"
	# Site-prefixed pack ids — same-named packs in two sites can never
	# cross-alert through the global pack groups.
	controller.pack_id = "%s:%s" % [chunk.site_id(), entry["pack"]]
	var patrol: Array = []
	for p in entry.get("patrol", []):
		patrol.append(chunk.to_global(p))
	controller.patrol_points = patrol
	controller.has_morale = entry.get("morale", false)
	# Bandit nerve: morale packs crack at 60% strength unless a site says
	# otherwise — scrappy raiders scatter early and slink back, they don't
	# stand and die.
	controller.morale_break_frac = entry.get("morale_frac",
		0.6 if entry.get("morale", false) else EnemyController.MORALE_BREAK_FRAC)
	controller.aggro_radius = entry.get("aggro", controller.aggro_radius)
	controller.pursue = entry.get("pursue", true)
	controller.disciplined = entry.get("disciplined", false)
	if entry.has("gear"):
		c.equip(load(entry["gear"]))
		c.select_slot(0)
	c.add_child(controller)
	_objectives.register(c, chunk.site_id(), entry.get("required", true))
	# Kill value for the squad XP pool — respawned packs pay half per repop
	# cycle, so pushing somewhere new always beats farming the refill.
	c.set_meta("xp_value", int(float(entry.get("xp", 10)) * pow(0.5, generation)))
	# Enemies get the full send-off; crew corpses stay for the squad read.
	c.character_died.connect(func(body):
		_award_kill_xp(body)
		Juice.death_collapse(body, true))
	return c

## Event spawns (the horde behind the seal): sites call this for one-shot
## releases — outside the respawn ledger, so once dead they stay dead.
func spawn_event_enemy(chunk: SiteChunk, entry: Dictionary) -> Character:
	return _spawn_enemy(chunk, entry)

## The squad pool credits any kill a crew member last touched — one pool,
## one crew level; the medic's revives count by keeping the shooters alive.
func _award_kill_xp(body: Character) -> void:
	if body.last_attacker != null and is_instance_valid(body.last_attacker) \
			and body.last_attacker.team == 0:
		GameState.add_xp(int(body.get_meta("xp_value", 10)))

## First-clear milestone: each site pays big ONCE per run — respawns
## un-clear the site but never re-arm the bonus.
const FIRST_CLEAR_XP := 120

func _on_site_cleared(site_id: String) -> void:
	if GameState.cleared_sites.has(site_id):
		return
	GameState.cleared_sites.append(site_id)
	GameState.add_xp(FIRST_CLEAR_XP)

## Level-up lands immediately on the live crew (curves); the perk PICKS
## wait for the hideout console — you get stronger by making it home.
func _on_crew_leveled(_new_level: int) -> void:
	for member in _squad.members:
		var c := member as Character
		if c == null or not is_instance_valid(c):
			continue
		c.max_hp += GameState.HP_PER_LEVEL
		c.max_shield += GameState.SHIELD_PER_LEVEL
		if c.is_alive():
			c.hp += GameState.HP_PER_LEVEL
			c.shield += GameState.SHIELD_PER_LEVEL
		c.hp_changed.emit(c.hp, c.max_hp)
		c.shield_changed.emit(c.shield, c.max_shield)
	AudioManager.play_sfx("levelup")

# ── Jobs: lift the take, then run it home ───────────────────────────────────

## While carrying, the owner's people within this radius get re-pinned on the
## carrier every tick — the word going out. Bounded on purpose: alerting the
## whole district at once turns every job into the same dogpile, and the
## pursuit AI already drags a pinned pack across site borders on its own.
const JOB_HUNT_RADIUS := 70.0
const JOB_HUNT_INTERVAL := 2.0

## Whatever the live contract put in the world: a pickup, a mark, a core, or
## a person. One handle, because only one job runs at a time.
var _job_nodes: Array = []
var _job_escort: JobEscort = null
var _job_hunt_t := 0.0

## Reconcile the world with GameState. Safe to call any time — the board
## calls it on accept/abandon, boot calls it for a restored save.
func refresh_job() -> void:
	for node in _job_nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	_job_nodes = []
	_job_escort = null
	if GameState.active_job == "":
		return
	var id := GameState.active_job
	var job := Jobs.job(id)
	var chunk: SiteChunk = _chunks_by_id.get(str(job.get("site", "")))
	if chunk == null:
		return
	if GameState.carrying:
		# Mid-contract reload. Only the escort has anything left in the world
		# to restore — the others are already in the crew's pocket. Put the
		# package back on the crew rather than back at the tower.
		if Jobs.type_of(id) == "escort":
			_build_escort(chunk, job)
			if _job_escort != null:
				_job_escort.following = true
				var active := _squad.active_character()
				if active != null and is_instance_valid(active) \
						and _job_nodes.size() > 0 and is_instance_valid(_job_nodes[0]):
					(_job_nodes[0] as Node3D).global_position = \
						active.global_position + Vector3(1.5, 0.0, 1.5)
		return
	match Jobs.type_of(id):
		"hit":
			_build_hit(chunk, job)
		"sabotage":
			var core := JobSabotage.build_objective(chunk, job)
			core.breached.connect(_on_objective_done)
			_job_nodes.append(core)
		"escort":
			_build_escort(chunk, job)
		_:
			var loot := JobLoot.spawn(chunk, job, self)
			loot.lifted.connect(_on_objective_done)
			_job_nodes.append(loot)

## The mark, plus a detail who die with him being nobody in particular.
func _build_hit(chunk: SiteChunk, job: Dictionary) -> void:
	var pos: Vector3 = job.get("pos", Vector3.ZERO)
	var mark := spawn_event_enemy(chunk, {
		"skin": str(job.get("mark_skin", "gangster")),
		"pos": pos, "pack": "job_mark", "required": false,
		"faction": Jobs.owner_of(GameState.active_job),
		"hp": float(job.get("mark_hp", 240.0)), "xp": 0, "aggro": 16.0,
		"gear": str(job.get("mark_gear", "res://resources/gear/enemy_rifle.tres")),
	})
	if mark == null:
		return
	var tag := Label3D.new()
	tag.text = "★ " + str(job.get("name", "MARK"))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 30
	tag.pixel_size = 0.004
	tag.outline_size = 8
	tag.modulate = Color(1.0, 0.45, 0.4)
	tag.position.y = 2.4
	mark.add_child(tag)
	mark.character_died.connect(func(_c): _on_objective_done())
	_job_nodes.append(mark)
	for i in int(job.get("guards", 0)):
		var guard := spawn_event_enemy(chunk, {
			"skin": "biker", "pack": "job_mark", "required": false,
			"pos": pos + Vector3(3.0 if i % 2 == 0 else -3.0, 0.0, -2.0),
			"faction": Jobs.owner_of(GameState.active_job),
			"hp": 70.0, "xp": 10,
			"gear": "res://resources/gear/enemy_smg.tres",
		})
		if guard != null:
			_job_nodes.append(guard)

## The package: unarmed, neutral, and hers to lose.
func _build_escort(chunk: SiteChunk, job: Dictionary) -> void:
	var person := spawn_event_enemy(chunk, {
		"skin": str(job.get("escort_skin", "suit")),
		"pos": job.get("pos", Vector3.ZERO), "pack": "job_escort",
		"faction": Factions.CIVIL, "required": false, "unarmed": true,
		"hp": 90.0, "xp": 0, "aggro": 0.0, "pursue": false,
	})
	if person == null:
		return
	_job_escort = JobEscort.attach(person, self)
	_job_escort.contacted.connect(_on_objective_done)
	# Losing the package is the fail state: the contract drops, and whatever
	# grudge the job earned stays earned.
	_job_escort.died.connect(func():
		if GameState.active_job != "" and Jobs.type_of(GameState.active_job) == "escort":
			($HUD as Hud).flash_job("THE INFORMANT IS DEAD — JOB LOST")
			AudioManager.play_sfx("down")
			GameState.abandon_job())
	_job_nodes.append(person)

## The moment that turns a walk into a getaway — shared by every job type,
## which is why they all feel like the same contract with different verbs.
func _on_objective_done() -> void:
	var id := GameState.active_job
	if id == "" or GameState.carrying:
		return
	GameState.lift_loot()
	var owner_faction := Jobs.owner_of(id)
	# An honor grudge outlives the hideout's rest; an ordinary one is
	# forgiven once the crew is home and breathing.
	if Jobs.lasting_grudge(id):
		Factions.provoke_lasting(owner_faction, Factions.CREW)
	else:
		Factions.provoke(owner_faction, Factions.CREW)
	AudioManager.play_sfx("telegraph")
	($HUD as Hud).flash_job("%s — GET CLEAR" % _done_banner(id))
	_hunt_carrier(true)

## What the completion banner says, per verb.
func _done_banner(id: String) -> String:
	var what := str(Jobs.job(id).get("loot", "IT"))
	match Jobs.type_of(id):
		"hit": return "THE MARK IS DOWN"
		"sabotage": return "THE CORE IS OUT"
		"escort": return "THE INFORMANT IS WITH YOU"
		_: return "%s TAKEN" % what

func _tick_jobs(delta: float) -> void:
	if not GameState.carrying:
		return
	_job_hunt_t -= delta
	if _job_hunt_t <= 0.0:
		_job_hunt_t = JOB_HUNT_INTERVAL
		_hunt_carrier(false)

## Re-pin the owner's nearby units on whoever is holding the take.
func _hunt_carrier(_first: bool) -> void:
	var carrier := _squad.active_character()
	if carrier == null or not is_instance_valid(carrier) or not carrier.is_alive():
		return
	var owner_faction := Jobs.owner_of(GameState.active_job)
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		var ec := node as EnemyController
		if ec == null or not is_instance_valid(ec.body) or not ec.body.is_alive():
			continue
		if ec.body.team != owner_faction:
			continue
		if ec.body.global_position.distance_to(carrier.global_position) > JOB_HUNT_RADIUS:
			continue
		ec.body.notify_shot_at(carrier)

## Banked at the hideout — the only place that takes delivery, and the only
## place that heals. This is also the game's mission-complete beat: it lands
## where the crew is safe, not as a popup over the bodies.
func _bank_job_if_carrying() -> void:
	if not GameState.carrying:
		return
	var job := Jobs.job(GameState.active_job)
	var paid := GameState.bank_job()
	if paid <= 0:
		return
	AudioManager.play_sfx("levelup")
	($HUD as Hud).flash_job("%s DELIVERED  ·  +%d XP" % [
		str(job.get("loot", "THE TAKE")), paid])
	# The package walked home; it doesn't loiter in the safe room afterwards.
	for node in _job_nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	_job_nodes = []
	_job_escort = null
	refresh_job()


# ── Site tracking: label, autosave, rest, respawn ────────────────────────────

func _tick_sites(delta: float) -> void:
	var active := _squad.active_character()
	if active != null and is_instance_valid(active):
		var p := Vector2(active.global_position.x, active.global_position.z)
		for chunk in _chunks:
			if (chunk as SiteChunk).bounds_rect().grow(2.0).has_point(p):
				if chunk.site_id() != _active_site:
					_enter_site(chunk)
				elif chunk.heals_crew():
					# Banking on ENTRY alone misses a contract that completes
					# while the crew is already stood in the safe room — an
					# escort catching up, say.
					_bank_job_if_carrying()
				break  # in a corridor, no chunk matches — the label stays put
	for chunk in _chunks:
		var id: String = chunk.site_id()
		if chunk.heals_crew():
			continue  # the hideout never repopulates
		var state: Dictionary = _site_state[id]
		if _crew_present(chunk):
			state["vacant"] = 0.0
		elif _site_has_dead(id):
			state["vacant"] += delta
			if state["vacant"] >= respawn_delay:
				_respawn_site(chunk)

func _enter_site(chunk: SiteChunk) -> void:
	_active_site = chunk.site_id()
	($HUD as Hud).set_site(chunk.site_name())
	_apply_mood(chunk)
	AudioManager.play_ambient(chunk.ambient())
	if chunk.heals_crew():
		_bank_job_if_carrying()  # deliver first, THEN rest forgives the heat
		_rest_crew()
	# Autosave on arrival: snapshot the living bodies, stamp the site.
	GameState.capture_crew()
	GameState.save_game(_active_site)

## The hideout rest: everyone standing is patched to full, the slate of
## grudges is wiped — the district forgives while you catch your breath.
func _rest_crew() -> void:
	for member in _squad.members:
		var c := member as Character
		if c == null or not is_instance_valid(c) or not c.is_alive():
			continue
		c.hp = c.max_hp
		c.shield = c.max_shield
		c.hp_changed.emit(c.hp, c.max_hp)
		c.shield_changed.emit(c.shield, c.max_shield)
	GameState.crew_state = {}
	Factions.reset_provocations()

func _crew_present(chunk: SiteChunk) -> bool:
	var bounds := chunk.bounds_rect().grow(6.0)
	for member in _squad.members:
		if not is_instance_valid(member):
			continue
		var pos: Vector3 = (member as Node3D).global_position
		if bounds.has_point(Vector2(pos.x, pos.z)):
			return true
	return false

func _site_has_dead(id: String) -> bool:
	for rec in _site_state[id]["records"]:
		var body = rec["body"]
		if not is_instance_valid(body) or not (body as Character).is_alive():
			return true
	return false

## The district refills behind you: once the crew has been gone a beat,
## corpses clear out and the site's packs stand back up.
func _respawn_site(chunk: SiteChunk) -> void:
	var id := chunk.site_id()
	var state: Dictionary = _site_state[id]
	state["vacant"] = 0.0
	state["gen"] = int(state.get("gen", 0)) + 1
	_objectives.clear_site(id)
	for rec in state["records"]:
		var body = rec["body"]
		if is_instance_valid(body) and (body as Character).is_alive():
			_objectives.register(body, id, rec["entry"].get("required", true))
		else:
			if is_instance_valid(body):
				body.queue_free()
			rec["body"] = _spawn_enemy(chunk, rec["entry"], state["gen"])

# ── Camera ───────────────────────────────────────────────────────────────────
# Two modes for the fun evaluation: the shipped ISO rig, and an
# over-the-shoulder mode on V — perspective, mouse-look, center reticle.
# Combat resolution is IDENTICAL in both (same cone acquire, same accuracy
# × cover model); only how the aim direction is produced changes.

const _OTS_FOV := 70.0
const _OTS_DIST := 2.6
const _OTS_SHOULDER := Vector3(0.65, 0.3, 0.0)  # right shoulder, slight rise
const _OTS_SENS := 0.0035
const _OTS_PITCH_MIN := -1.15
const _OTS_PITCH_MAX := 0.55

var _ots := false
var _ots_yaw := 0.0
var _ots_pitch := -0.15

func ots_active() -> bool:
	return _ots

## Toggle (V, or harness call). ISO restores the rig wholesale.
func set_camera_mode(ots: bool) -> void:
	if _ots == ots:
		return
	_ots = ots
	if _ots:
		_ots_yaw = _ISO_YAW  # start facing the iso "north" the player knows
		_ots_pitch = -0.15
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.fov = _OTS_FOV
		_camera.near = 0.15
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_setup_camera()

func _setup_camera() -> void:
	_cam_pivot.rotation = Vector3(0.0, _ISO_YAW, 0.0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _zoom
	_camera.rotation = Vector3(_ISO_PITCH, 0.0, 0.0)
	_camera.position = Vector3(0.0, sin(-_ISO_PITCH) * _ISO_DIST, cos(_ISO_PITCH) * _ISO_DIST)
	_camera.near = 0.5
	_camera.far = 200.0
	var active := _squad.active_character()
	if active != null:
		_cam_pivot.global_position = active.global_position

## Manual spring arm: pull the camera in when world geometry sits between
## the shoulder pivot and the ideal position.
func _tick_ots_camera(active: Character) -> void:
	var pivot := active.global_position \
		+ Vector3(0, 1.5 * Character.VERTICAL_SQUASH, 0)
	var rot := Basis.from_euler(Vector3(_ots_pitch, _ots_yaw, 0.0))
	var ideal := pivot + rot * (_OTS_SHOULDER + Vector3(0, 0, _OTS_DIST))
	var query := PhysicsRayQueryParameters3D.create(pivot, ideal,
		Layers.GROUND | Layers.COVER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		ideal = (hit["position"] as Vector3) + (pivot - ideal).normalized() * 0.2
	_camera.global_position = ideal
	_camera.global_transform.basis = rot

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var active := _squad.active_character()
	if active != null and is_instance_valid(active):
		AudioManager.listener_pos = active.global_position
	if _ots:
		if active != null and is_instance_valid(active):
			_tick_ots_camera(active)
		_tick_sites(delta)
		_tick_jobs(delta)
		return
	if active != null and is_instance_valid(active):
		_cam_pivot.global_position = _cam_pivot.global_position.lerp(
			active.global_position, minf(1.0, _CAM_FOLLOW_SPEED * delta))
	_camera.size = lerpf(_camera.size, _zoom, minf(1.0, 10.0 * delta))
	_tick_sites(delta)
	_tick_jobs(delta)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _ots and event is InputEventMouseMotion:
		_ots_yaw -= (event as InputEventMouseMotion).relative.x * _OTS_SENS
		_ots_pitch = clampf(
			_ots_pitch - (event as InputEventMouseMotion).relative.y * _OTS_SENS,
			_OTS_PITCH_MIN, _OTS_PITCH_MAX)
		return
	if event is InputEventMouseButton and event.pressed and not _ots:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(_ZOOM_MIN, _zoom - _ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(_ZOOM_MAX, _zoom + _ZOOM_STEP)
	elif event.is_action_pressed("toggle_camera") and not _game_over:
		set_camera_mode(not _ots)
	elif event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	elif event.is_action_pressed("district_map") and not _game_over:
		DistrictMap.toggle(self, _active_site)

# ── Pause ────────────────────────────────────────────────────────────────────

var _pause_layer: CanvasLayer = null

func _toggle_pause() -> void:
	if _game_over:
		return
	if _pause_layer != null:
		_close_pause()
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # menus need a pointer
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 60
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = UITheme.theme
	panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "VANTAG DISTRICT"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.C_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(_close_pause)
	vbox.add_child(resume)
	var restart := Button.new()
	restart.text = "Restart District"
	restart.pressed.connect(func():
		_close_pause()
		SceneManager.reload_current())
	vbox.add_child(restart)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit)

func _close_pause() -> void:
	if _pause_layer != null:
		_pause_layer.queue_free()
		_pause_layer = null
	get_tree().paused = false
	if _ots:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ── Squad wiped ──────────────────────────────────────────────────────────────

func _show_wipe_screen() -> void:
	if _game_over:
		return
	_game_over = true
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel := PanelContainer.new()
	panel.theme = UITheme.theme
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "SQUAD WIPED"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", UITheme.C_HP_ENEMY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var retry := Button.new()
	retry.text = "Retry"
	retry.pressed.connect(func(): SceneManager.reload_current())
	vbox.add_child(retry)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit)
