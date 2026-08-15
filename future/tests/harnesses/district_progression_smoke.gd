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
	for pack in ["mid", "east", "west", "roof"]:
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
	_check(street.size() == 9, "street starts with 9 (got %d)" % street.size())
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
	# 7 remaining bodies (six 10-XP gangers + the 15-XP roof lookout) plus
	# the 120 first-clear, on top of the single credited kill from step 1.
	_check(GameState.xp == 10 + 6 * 10 + 15 + 120,
		"the rest of the street + first-clear pays out (xp %d)" % GameState.xp)
	_check(_clears == 1 and GameState.cleared_sites.has("skirmish"),
		"street first-clear fired and is remembered")

	# 3. Crossing the threshold levels the crew LIVE (curves, not just
	#    numbers). Level-relative, so retuning any site's XP can't break it.
	var lvl_before := GameState.crew_level
	var hp_max_before := leader.max_hp
	GameState.add_xp(GameState.threshold_for(lvl_before + 1) - GameState.xp + 1)
	await _settle(2)
	_check(GameState.crew_level == lvl_before + 1,
		"crossing the threshold levels the crew (%d → %d)"
		% [lvl_before, GameState.crew_level])
	_check(is_equal_approx(leader.max_hp, hp_max_before + GameState.HP_PER_LEVEL),
		"level-up raises live max hp (%.0f -> %.0f)" % [hp_max_before, leader.max_hp])

	# 4. Respawned packs pay HALF, and the milestone never re-arms.
	_world.respawn_delay = 1.0
	await get_tree().create_timer(2.5).timeout
	await _settle(3)
	var repop := _street_controllers()
	_check(repop.size() == 9, "street repopulated for the discount test (got %d)" % repop.size())
	var xp_before_repop_kills := GameState.xp
	for ec in repop:
		ec.body.receive_damage(9999.0, leader)
	await _settle(3)
	var repop_expected := xp_before_repop_kills + 8 * 5 + 7  # lookout: 15 → 7
	_check(GameState.xp == repop_expected,
		"respawned kills pay half, no second milestone (xp %d, expected %d)"
		% [GameState.xp, repop_expected])
	_check(_clears == 2, "the site still CLEARS again (%d) — only the bonus is once" % _clears)

	# 5. Perk picks: one owed per level past the first, spent once each,
	#    applied to the body.
	var owed := GameState.picks_owed("leader")
	_check(owed == GameState.crew_level - 1,
		"one pick owed per level past the first (%d at level %d)"
		% [owed, GameState.crew_level])
	_check(GameState.take_perk("leader", "dead_eye"), "leader takes Dead Eye")
	Perks.apply(leader, "dead_eye")
	for spare in range(owed - 1):
		GameState.take_perk("leader", ["cap_rig", "scar_tissue", "stims"][spare % 3])
	_check(not GameState.take_perk("leader", "quick_hands"),
		"picks run out once they are all spent")
	_check(absf(leader.damage_mult - 1.15) < 0.001, "Dead Eye applies +15%% damage")

	# 6. Progression persists through the save (scratch slot; the world boot
	#    flagged this run as a debug session — lift that for the write).
	const TEST_SLOT := 9
	GameState.debug_session = false
	_check(GameState.save_game("skirmish", TEST_SLOT), "progression save writes")
	var xp_saved := GameState.xp
	GameState.xp = 0
	GameState.perks = {}
	GameState.cleared_sites = []
	var lvl_saved := GameState.crew_level
	GameState.crew_level = 1
	GameState.load_game(TEST_SLOT)
	_check(GameState.xp == xp_saved and GameState.crew_level == lvl_saved
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
