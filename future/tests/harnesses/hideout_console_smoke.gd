## Headless hideout-console smoke — run with:
##   godot --headless res://future/tests/harnesses/hideout_console_smoke.tscn
## The console is the run's whole out-of-combat surface and now routes three
## ways: owed talent points open the crew tree, otherwise the job board, and
## the district map stays on M regardless. Walking up to it must never open
## nothing, and never open two things at once.
extends Node

var _failures: Array[String] = []
var _world: GameWorld

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

func _panels() -> Dictionary:
	var out := {"tree": 0, "board": 0, "map": 0}
	for node in _world.find_children("*", "", true, false):
		if node is TrainingPanel:
			out["tree"] += 1
		elif node is JobBoard:
			out["board"] += 1
		elif node is DistrictMap:
			out["map"] += 1
	return out

## Walk the active character onto the console pad and let the Area3D fire.
func _walk_up() -> void:
	var hideout := _world.get_node("Level/Hideout") as SiteChunk
	var leader := _world.active_character()
	leader.global_position = hideout.to_global(Vector3(0.0, 0.1, 6.0))
	await _settle(5)
	leader.global_position = hideout.to_global(Vector3(0.0, 0.1, -4.0))
	await _settle(8)

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	GameState.start_site = "hideout"
	GameState.xp = 0
	GameState.crew_level = 1
	GameState.talents = {}
	GameState.cleared_sites = []
	GameState.active_job = ""
	GameState.carrying = false
	GameState.completed_jobs = []
	_world = load("res://scenes/district.tscn").instantiate()
	add_child(_world)
	for i in 600:
		await get_tree().physics_frame
		if GameState.squad.size() == 4:
			break
	if GameState.squad.size() != 4:
		printerr("FAIL: crew never spawned")
		print("HIDEOUT_CONSOLE_SMOKE: 1 FAILURES")
		get_tree().quit(1)
		return
	await _settle(15)

	# 1. Fresh level-1 crew owes no points → the console is the JOB BOARD.
	_check(GameState.talent_points_owed() == 0, "a level-1 crew owes no points")
	await _walk_up()
	var p := _panels()
	_check(p["board"] == 1 and p["tree"] == 0,
		"with nothing to train, the console opens the job board (board %d, tree %d)"
		% [p["board"], p["tree"]])
	JobBoard.toggle(_world, _world)  # close
	await _settle(3)

	# 2. Level the crew → points owed → the console opens the CREW TREE.
	GameState.add_xp(GameState.threshold_for(3))
	_check(GameState.talent_points_owed() > 0,
		"levelling owes points (%d)" % GameState.talent_points_owed())
	await _walk_up()
	p = _panels()
	_check(p["tree"] == 1 and p["board"] == 0,
		"with points owed, the console opens the crew tree (tree %d, board %d)"
		% [p["tree"], p["board"]])
	TrainingPanel.toggle(_world, _world)
	await _settle(3)

	# 3. Spend every point → the console goes back to the board.
	var guard := 0
	while GameState.talent_points_owed() > 0 and guard < 40:
		guard += 1
		if not GameState.buy_talent("toughness") \
				and not GameState.buy_talent("capacitor") \
				and not GameState.buy_talent("marksman"):
			break
	_check(GameState.talent_points_owed() == 0,
		"tier-1 nodes can absorb the early points (%d left)"
		% GameState.talent_points_owed())
	await _walk_up()
	p = _panels()
	_check(p["board"] == 1 and p["tree"] == 0,
		"points spent, the console returns to the job board")
	JobBoard.toggle(_world, _world)
	await _settle(3)

	# 4. The map is still reachable independently and is its own panel.
	DistrictMap.toggle(_world, "hideout")
	await _settle(3)
	p = _panels()
	_check(p["map"] == 1, "the district map still opens on its own")
	DistrictMap.toggle(_world, "hideout")

	if _failures.is_empty():
		print("HIDEOUT_CONSOLE_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("HIDEOUT_CONSOLE_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
