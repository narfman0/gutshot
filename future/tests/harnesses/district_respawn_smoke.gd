## Headless respawn-cycle smoke — run with:
##   godot --headless res://future/tests/harnesses/district_respawn_smoke.tscn
## The district refills behind you: clearing a site fires site_cleared, a
## vacated cleared site repopulates after the delay, and crew presence
## blocks the repop until they actually leave.
extends Node

var _failures: Array[String] = []
var _world: GameWorld
var _cleared: Array = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

func _chunk(site: String) -> SiteChunk:
	return _world.get_node("Level/" + site) as SiteChunk

func _street_alive() -> int:
	var count := 0
	for pack in ["mid", "east", "west"]:
		for node in get_tree().get_nodes_in_group("pack_skirmish:" + pack):
			var ec := node as EnemyController
			if ec != null and is_instance_valid(ec.body) and ec.body.is_alive():
				count += 1
	return count

func _kill_street() -> void:
	for pack in ["mid", "east", "west"]:
		for node in get_tree().get_nodes_in_group("pack_skirmish:" + pack):
			var ec := node as EnemyController
			if ec != null and is_instance_valid(ec.body) and ec.body.is_alive():
				ec.body.receive_damage(9999.0)

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	GameState.start_site = "hideout"
	_world = load("res://scenes/district.tscn").instantiate()
	add_child(_world)
	for i in 600:
		await get_tree().physics_frame
		if GameState.squad.size() == 4:
			break
	if GameState.squad.size() != 4:
		printerr("FAIL: crew never spawned — world boot broken")
		print("DISTRICT_RESPAWN_SMOKE: 1 FAILURES")
		get_tree().quit(1)
		return
	_world.respawn_delay = 1.0
	var objectives := _world.get_node("ObjectiveManager") as ObjectiveManager
	objectives.site_cleared.connect(func(site_id): _cleared.append(site_id))

	# 1. Clearing the street fires site_cleared.
	_check(_street_alive() == 7, "street starts with 7 gang members")
	_kill_street()
	await _settle(3)
	_check(_cleared.has("skirmish"), "clearing the street fires site_cleared")
	_check(objectives.site_clear("skirmish"), "objectives report the street clear")

	# 2. Crew is at the hideout (not present) → the site repopulates.
	await get_tree().create_timer(2.0).timeout
	await _settle(3)
	_check(_street_alive() == 7, "vacated street repopulates (%d alive)" % _street_alive())
	_check(not objectives.site_clear("skirmish"), "repop un-clears the site")

	# 3. Crew standing IN the site blocks the repop until they leave.
	var leader := GameState.squad[0] as Character
	leader.global_position = _chunk("Street").to_global(Vector3(0, 0.1, 18))
	await _settle(5)
	_kill_street()
	await get_tree().create_timer(2.0).timeout
	_check(_street_alive() == 0, "crew presence blocks the repop (%d alive)" % _street_alive())
	leader.global_position = _chunk("Hideout").to_global(Vector3(0, 0.1, 4))
	# The rest of the crew followed the leader into the street — pull them out
	# too so the site actually vacates.
	for member in GameState.squad:
		(member as Character).global_position = _chunk("Hideout").to_global(Vector3(0, 0.1, 5))
	await get_tree().create_timer(2.0).timeout
	await _settle(3)
	_check(_street_alive() == 7, "leaving lets the street refill (%d alive)" % _street_alive())

	if _failures.is_empty():
		print("DISTRICT_RESPAWN_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_RESPAWN_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
