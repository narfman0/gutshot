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
	_check(travelable == 2, "two other sites travelable from the hideout (got %d)" % travelable)
	world.free()

	if _failures.is_empty():
		print("DISTRICT_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
