## Headless progression smoke — run with:
##   godot --headless res://future/tests/harnesses/district_progression_smoke.tscn
## The squad XP pool: crew-credited kills pay, uncredited deaths don't,
## first-clears pay the milestone exactly once, respawned packs pay half,
## levels land live on the crew, perk picks are owed/spent/persisted.
extends Node

var _failures: Array[String] = []
var _world: GameWorld
var _clears := 0

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

func _street_controllers() -> Array:
	var out: Array = []
	for pack in ["mid", "east", "west"]:
		for node in get_tree().get_nodes_in_group("pack_skirmish:" + pack):
			if is_instance_valid(node):
				var ec := node as EnemyController
				if is_instance_valid(ec.body) and ec.body.is_alive():
					out.append(ec)
	return out

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	GameState.start_site = "hideout"
	GameState.xp = 0
	GameState.crew_level = 1
	GameState.perks = {}
	GameState.cleared_sites = []
	_world = load("res://scenes/district.tscn").instantiate()
	add_child(_world)
	for i in 600:
		await get_tree().physics_frame
		if GameState.squad.size() == 4:
			break
	if GameState.squad.size() != 4:
		printerr("FAIL: crew never spawned — world boot broken")
		print("DISTRICT_PROGRESSION_SMOKE: 1 FAILURES")
		get_tree().quit(1)
		return
	_world.respawn_delay = 9999.0
	await _settle(15)
	var leader := GameState.squad[0] as Character
	(_world.get_node("ObjectiveManager") as ObjectiveManager) \
		.site_cleared.connect(func(_id): _clears += 1)

	# 1. Credited kill pays; an uncredited death pays nothing.
	var street := _street_controllers()
	_check(street.size() == 8, "street starts with 8 (got %d)" % street.size())
	(street[0] as EnemyController).body.receive_damage(9999.0, leader)
	await _settle(2)
	_check(GameState.xp == 10, "crew-credited kill pays 10 (xp %d)" % GameState.xp)
	(street[1] as EnemyController).body.receive_damage(9999.0)
	await _settle(2)
	_check(GameState.xp == 10, "uncredited death pays nothing (xp %d)" % GameState.xp)

	# 2. First-clear milestone pays once on top of the kills.
	for ec in _street_controllers():
		ec.body.receive_damage(9999.0, leader)
	await _settle(3)
	_check(GameState.xp == 190, "6 kills + 120 first-clear = 190 (xp %d)" % GameState.xp)
	_check(_clears == 1 and GameState.cleared_sites.has("skirmish"),
		"street first-clear fired and is remembered")

	# 3. Crossing the threshold levels the crew LIVE (curves, not just numbers).
	var hp_max_before := leader.max_hp
	GameState.add_xp(10)  # 200 total → level 2
	await _settle(2)
	_check(GameState.crew_level == 2, "200 xp reaches crew level 2")
	_check(is_equal_approx(leader.max_hp, hp_max_before + GameState.HP_PER_LEVEL),
		"level-up raises live max hp (%.0f -> %.0f)" % [hp_max_before, leader.max_hp])

	# 4. Respawned packs pay HALF, and the milestone never re-arms.
	_world.respawn_delay = 1.0
	await get_tree().create_timer(2.5).timeout
	await _settle(3)
	var repop := _street_controllers()
	_check(repop.size() == 8, "street repopulated for the discount test (got %d)" % repop.size())
	var xp_before_repop_kills := GameState.xp
	for ec in repop:
		ec.body.receive_damage(9999.0, leader)
	await _settle(3)
	_check(GameState.xp == xp_before_repop_kills + 8 * 5,
		"respawned kills pay half, no second milestone (xp %d, expected %d)"
		% [GameState.xp, xp_before_repop_kills + 40])
	_check(_clears == 2, "the site still CLEARS again (%d) — only the bonus is once" % _clears)

	# 5. Perk picks: owed by level, spent once, applied to the body.
	_check(GameState.picks_owed("leader") == 1, "level 2 owes the leader one pick")
	_check(GameState.take_perk("leader", "dead_eye"), "leader takes Dead Eye")
	_check(not GameState.take_perk("leader", "cap_rig"), "no picks left at level 2")
	Perks.apply(leader, "dead_eye")
	_check(absf(leader.damage_mult - 1.15) < 0.001, "Dead Eye applies +15%% damage")

	# 6. Progression persists through the save (scratch slot; the world boot
	#    flagged this run as a debug session — lift that for the write).
	const TEST_SLOT := 9
	GameState.debug_session = false
	_check(GameState.save_game("skirmish", TEST_SLOT), "progression save writes")
	var xp_saved := GameState.xp
	GameState.xp = 0
	GameState.crew_level = 1
	GameState.perks = {}
	GameState.cleared_sites = []
	GameState.load_game(TEST_SLOT)
	_check(GameState.xp == xp_saved and GameState.crew_level == 2
		and GameState.perks.get("leader", []).has("dead_eye")
		and GameState.cleared_sites.has("skirmish"),
		"save round-trips xp/level/perks/cleared")
	DirAccess.remove_absolute(SaveManager._path(TEST_SLOT))
	GameState.debug_session = true

	if _failures.is_empty():
		print("DISTRICT_PROGRESSION_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_PROGRESSION_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
