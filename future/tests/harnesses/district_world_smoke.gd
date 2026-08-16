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

	# 2b. The tower branches off the street — the plaza is walkable too.
	var t_from := (_chunk("Street") as Node3D).global_position + Vector3(0, 0.1, 0)
	var t_to := (_chunk("Tower") as Node3D).global_position + Vector3(0, 0.1, 0)
	var t_path := NavigationServer3D.map_get_path(map, t_from, t_to, true)
	var t_end := t_path[t_path.size() - 1] if t_path.size() > 0 else Vector3.INF
	_check(t_path.size() > 1 and Vector2(t_end.x - t_to.x, t_end.z - t_to.z).length() < 6.0,
		"Street → Tower is walkable (path %d pts)" % t_path.size())

	# 2c. Interiors are REAL rooms: pathable through the doorway, and walled
	#     against sight from outside (you must go in, or shoot through the
	#     door you can see).
	var street_chunk := _chunk("Street")
	var shop_inside := street_chunk.to_global(Vector3(-16.0, 0.1, -20.0))
	var shop_path := NavigationServer3D.map_get_path(
		map, street_chunk.to_global(Vector3(-16.0, 0.1, -8.0)), shop_inside, true)
	var shop_end := shop_path[shop_path.size() - 1] if shop_path.size() > 0 else Vector3.INF
	_check(shop_path.size() > 1
			and Vector2(shop_end.x - shop_inside.x, shop_end.z - shop_inside.z).length() < 2.0,
		"the chop shop can be walked into (path %d pts)" % shop_path.size())
	var eye_out := street_chunk.to_global(Vector3(-16.0, 1.4, -8.0))
	var eye_in := street_chunk.to_global(Vector3(-19.0, 1.4, -22.5))
	var space := _world.get_world_3d().direct_space_state
	var blocked: Dictionary = space.intersect_ray(
		PhysicsRayQueryParameters3D.create(eye_out, eye_in, Layers.LOS_MASK))
	_check(not blocked.is_empty(), "its back corner is out of sight from the street")

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

	# 7. The crew FOLLOWS. Playtest 2026-08-15: the party kept stopping to
	#    fight and getting left behind, so following must now outrank
	#    fighting past a catch-up distance — proven in the worst case, with
	#    the leader walking off through hostile turf.
	# A downed leader hands control to the next crew member, and the crew
	# then correctly follows THAT one — so the test has to hold control still
	# to mean anything. Make squad[0] a bullet sponge.
	leader.max_hp = 1000000.0
	leader.hp = leader.max_hp
	leader.global_position = street.to_global(Vector3(0, 0.1, 18))
	await _settle(20)
	var followers: Array = []
	for member in GameState.squad:
		var c := member as Character
		if c != null and c != leader and is_instance_valid(c) and c.is_alive():
			followers.append(c)
	_check(followers.size() == 3, "three followers to test (got %d)" % followers.size())
	# March the leader the length of the street, through the gang packs.
	leader.global_position = street.to_global(Vector3(0, 0.1, -18))
	var closed := 0
	for k in 20:
		await get_tree().create_timer(0.5).timeout
		closed = 0
		for f in followers:
			var c := f as Character
			if is_instance_valid(c) and c.is_alive() \
					and c.global_position.distance_to(leader.global_position) \
						<= SquadFollow.CATCHUP_DIST:
				closed += 1
		if closed >= 2:
			break
	_check(_world.active_character() == leader,
		"the sponge leader is still the one being controlled")
	_check(closed >= 2,
		"the crew closes on the leader even through a fight (%d of %d within %.0f m)"
		% [closed, followers.size(), SquadFollow.CATCHUP_DIST])

	# 8. The district is QUIET when you walk in. Playtest 2026-08-15: several
	#    factions were already shooting each other at boot. NPC factions that
	#    merely dislike each other now stand off until provoked; the crew and
	#    the Spawn are the exemptions.
	Factions.reset_all()
	_check(not Factions.engages_on_sight(Factions.GANGS, Factions.CLAN),
		"gangs and the clan do not start it on sight")
	_check(not Factions.engages_on_sight(Factions.GANGS, Factions.CORP),
		"gangs and corp security do not start it on sight")
	_check(Factions.engages_on_sight(Factions.GANGS, Factions.CREW),
		"but the gangs still jump the CREW on sight — that is the game")
	_check(Factions.engages_on_sight(Factions.HORDE, Factions.CLAN),
		"and the Spawn still attacks everything")
	# Provoked, they fight properly.
	Factions.provoke(Factions.GANGS, Factions.CLAN)
	_check(Factions.engages_on_sight(Factions.GANGS, Factions.CLAN),
		"once provoked, they DO engage on sight")
	Factions.reset_provocations()
	# And nobody is actually shooting in Little Japan at rest — the site that
	# ships a standing gang-vs-clan stand-off.
	var lj := _chunk("Littlejapan")
	leader.global_position = _chunk("Hideout").to_global(Vector3(0, 0.1, 4))
	await _settle(30)
	var fighting := 0
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		var ec := node as EnemyController
		if ec == null or not is_instance_valid(ec.body) or not ec.body.is_alive():
			continue
		if not lj.bounds_rect().grow(2.0).has_point(
				Vector2(ec.body.global_position.x, ec.body.global_position.z)):
			continue
		if ec.state == EnemyController.State.FIGHT:
			fighting += 1
	_check(fighting == 0,
		"Little Japan is calm with the crew away (%d in a fight)" % fighting)

	if _failures.is_empty():
		print("DISTRICT_WORLD_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_WORLD_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
