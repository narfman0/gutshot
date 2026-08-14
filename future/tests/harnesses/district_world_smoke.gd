## Headless seamless-district smoke — run with:
##   godot --headless res://future/tests/harnesses/district_world_smoke.tscn
## Asserts the world boots as ONE scene: crew spawns at the hideout, the
## walking chain hideout→street→exchange→depot→fab is navigable through the
## connector corridors, site tracking follows the active character, the
## hideout rest heals + forgives provocations, the map overlay is
## informational, and the save API round-trips on a scratch slot.
extends Node

var _failures: Array[String] = []
var _world: GameWorld

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

func _chunk(site: String) -> SiteChunk:
	return _world.get_node("Level/" + site) as SiteChunk

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	GameState.start_site = "hideout"
	_world = load("res://scenes/district.tscn").instantiate()
	add_child(_world)
	# Boot includes the full district bake — poll rather than fixed-wait.
	for i in 600:
		await get_tree().physics_frame
		if GameState.squad.size() == 4:
			break
	if GameState.squad.size() != 4:
		printerr("FAIL: crew never spawned — world boot broken")
		print("DISTRICT_WORLD_SMOKE: 1 FAILURES")
		get_tree().quit(1)
		return
	# Nav queries need the map's first synchronization after region
	# registration — give boot a proper beat, not a token one.
	await _settle(15)

	# 1. Crew starts inside the hideout, and the tracker knows it.
	var hideout := _chunk("Hideout")
	var leader := GameState.squad[0] as Character
	_check(hideout.bounds_rect().has_point(
		Vector2(leader.global_position.x, leader.global_position.z)),
		"crew spawns inside the hideout bounds")
	_check(_world.active_site_id() == "hideout",
		"active site is the hideout (got %s)" % _world.active_site_id())
	_check(AudioManager.ambient_name() == "ambient_hideout",
		"hideout plays its own bed (got %s)" % AudioManager.ambient_name())

	# 2. The walking chain is one navmesh: every leg paths through its corridor.
	var map := _world.get_world_3d().navigation_map
	var chain := ["Hideout", "Street", "Exchange", "Depot", "Fab"]
	for i in range(chain.size() - 1):
		var from := (_chunk(chain[i]) as Node3D).global_position + Vector3(0, 0.1, 0)
		var to := (_chunk(chain[i + 1]) as Node3D).global_position + Vector3(0, 0.1, 0)
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		var end := path[path.size() - 1] if path.size() > 0 else Vector3.INF
		var ok := path.size() > 1 and Vector2(end.x - to.x, end.z - to.z).length() < 6.0
		_check(ok, "%s → %s is walkable (path %d pts, gap %.1f)" % [chain[i],
			chain[i + 1], path.size(),
			Vector2(end.x - to.x, end.z - to.z).length() if path.size() > 0 else -1.0])

	# 3. Site tracking follows the active character across the district.
	var street := _chunk("Street")
	leader.global_position = street.to_global(Vector3(0, 0.1, 18))
	await _settle(5)
	_check(_world.active_site_id() == "skirmish",
		"walking into the street flips the active site (got %s)" % _world.active_site_id())
	_check(AudioManager.ambient_name() == "ambient_city",
		"the street crossfades to the city bed (got %s)" % AudioManager.ambient_name())

	# 4. Hideout rest: wounds close, grudges reset.
	leader.receive_damage(30.0)
	Factions.provoke(Factions.CREW, Factions.ASSEMBLY)
	leader.global_position = hideout.to_global(Vector3(0, 0.1, 4))
	await _settle(5)
	_check(leader.hp == leader.max_hp, "hideout rest heals the crew (hp %.0f)" % leader.hp)
	_check(not Factions.hostile(Factions.CREW, Factions.ASSEMBLY),
		"hideout rest forgives provocations")

	# 5. District map: informational — lists every site, offers no travel.
	DistrictMap.toggle(_world, "hideout")
	await get_tree().process_frame
	var labels := 0
	var buttons := 0
	for map_node in _world.get_children():
		if map_node is DistrictMap:
			labels = map_node.find_children("*", "Label", true, false).size()
			buttons = map_node.find_children("*", "Button", true, false).size()
	_check(labels >= DistrictMap.SITES.size(), "map lists every site (%d labels)" % labels)
	_check(buttons == 1, "map offers no travel — close button only (got %d)" % buttons)
	DistrictMap.toggle(_world, "hideout")

	# 6. Saves: debug sessions refuse; a real flag round-trips a scratch slot.
	const TEST_SLOT := 9
	GameState.debug_session = true
	_check(not GameState.save_game("skirmish", TEST_SLOT), "debug sessions never save")
	GameState.debug_session = false
	_check(GameState.save_game("depot", TEST_SLOT), "scratch-slot save writes")
	_check(GameState.load_game(TEST_SLOT) == "depot", "load returns the saved site")
	DirAccess.remove_absolute(SaveManager._path(TEST_SLOT))
	GameState.debug_session = true

	if _failures.is_empty():
		print("DISTRICT_WORLD_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_WORLD_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
