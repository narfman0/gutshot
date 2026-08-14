## Headless district smoke — run with:
##   godot --headless res://future/tests/harnesses/district_smoke.tscn
## Boots the main menu and the hideout: the safe room spawns the crew with
## zero enemies and never ends the mission; the district map opens and lists
## travelable sites.
extends Node

var _failures: Array[String] = []
var _ended := false

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _ready() -> void:
	# Menu scene builds without error.
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	_check(menu.get_child_count() > 0, "main menu builds its UI")
	menu.free()

	# Hideout: crew, no enemies, no mission end.
	GameState.squad = []
	GameState.debug_session = false
	GameState.mission_ended.connect(func(_v): _ended = true)
	var world: GameWorld = load("res://scenes/levels/hideout.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().physics_frame
	_check(GameState.squad.size() == 4, "crew spawns in the hideout")
	_check(get_tree().get_nodes_in_group("team_1").is_empty(), "no enemies in the safe room")
	await get_tree().create_timer(1.0).timeout
	_check(not _ended, "hideout never fires a mission end")

	# District map overlay: opens, lists sites, unlocked ones are travelable.
	DistrictMap.toggle(world, "hideout")
	await get_tree().process_frame
	var buttons := 0
	var travelable := 0
	for map_node in world.get_children():
		if map_node is DistrictMap:
			for button in map_node.find_children("*", "Button", true, false):
				buttons += 1
				if not (button as Button).disabled and (button as Button).text != "Close  (M)":
					travelable += 1
	_check(buttons >= DistrictMap.SITES.size(), "district map lists every site")
	_check(travelable == 3, "three other sites travelable from the hideout (got %d)" % travelable)
	world.free()

	# Save/load stub: round trip on a SCRATCH slot; debug sessions refuse.
	const TEST_SLOT := 9
	GameState.debug_session = true
	_check(not GameState.save_game("skirmish", TEST_SLOT), "debug sessions never save")
	GameState.debug_session = false
	GameState.crew_state = {"leader": {"hp": 42.0, "shield": 10.0}}
	_check(GameState.save_game("depot", TEST_SLOT), "real runs save")
	GameState.crew_state = {}
	var site := GameState.load_game(TEST_SLOT)
	_check(site == "depot", "load returns the saved site (got %s)" % site)
	_check(float(GameState.crew_state.get("leader", {}).get("hp", 0.0)) == 42.0,
		"crew condition survives the round trip")
	DirAccess.remove_absolute(SaveManager._path(TEST_SLOT))

	# Carried wounds apply on spawn. Squad cleared → the debug fallback flags
	# the session, so this boot can't autosave over anyone's real slot.
	GameState.squad = []
	var wounded: GameWorld = load("res://scenes/levels/skirmish.tscn").instantiate()
	add_child(wounded)
	for i in 10:
		await get_tree().physics_frame
	_check(GameState.debug_session, "harness boot flags debug (no autosave)")
	var leader := GameState.squad[0] as Character
	# The medic starts beaming the wounded leader immediately (working as
	# intended) — assert the wound carried, not an exact number.
	_check(leader.hp >= 42.0 and leader.hp < leader.max_hp * 0.7,
		"carried hp applies at a combat site (hp %.0f)" % leader.hp)
	wounded.free()
	await get_tree().physics_frame

	if _failures.is_empty():
		print("DISTRICT_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
