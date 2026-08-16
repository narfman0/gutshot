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
	GameState.talents = {}
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

	# 5. The crew tree: points accrue per level, tiers stay sealed until their
	#    milestone, prerequisites hold, and a purchase lands on the live body.
	var owed := GameState.talent_points_owed()
	_check(owed == (GameState.crew_level - 1) * GameState.POINTS_PER_LEVEL,
		"points owed = %d per level past the first (%d at level %d)"
		% [GameState.POINTS_PER_LEVEL, owed, GameState.crew_level])
	_check(Talents.can_buy("toughness"), "a tier-1 node is open from the start")
	_check(not Talents.can_buy("steady_aim"),
		"a tier-3 node is sealed at crew level %d" % GameState.crew_level)
	_check(not Talents.can_buy("quick_hands"),
		"a tier-2 node is refused without its prerequisite ranks")
	var hp_before := leader.max_hp
	_check(GameState.buy_talent("toughness"), "the crew buys Scar Tissue")
	Talents.apply_rank(leader, "leader", "toughness")
	_check(is_equal_approx(leader.max_hp, hp_before + 12.0),
		"the rank lands on the live body (%.0f -> %.0f)" % [hp_before, leader.max_hp])
	_check(GameState.talent_points_owed() == owed - 1, "the point is spent")
	# Rank cap holds even with points to burn.
	for i in 6:
		GameState.buy_talent("toughness")
	_check(Talents.ranks_in("toughness") <= int(Talents.node("toughness")["ranks"]),
		"a node never exceeds its rank cap (%d)" % Talents.ranks_in("toughness"))
	# Climb to the tier-2 milestone. The gate is the LEVEL; the prerequisite
	# is a second, independent lock — check they hold separately.
	GameState.add_xp(GameState.threshold_for(Talents.TIER_LEVEL[2]) - GameState.xp + 1)
	_check(GameState.crew_level >= int(Talents.TIER_LEVEL[2]),
		"the crew reaches the tier-2 milestone (level %d)" % GameState.crew_level)
	# Set the tree to a known state — writing ranks directly also spends the
	# points they represent, so leave the crew clearly in credit either way.
	GameState.talents = {}
	_check(GameState.talent_points_owed() > 0,
		"points are available for the prerequisite check (%d)"
		% GameState.talent_points_owed())
	_check(not Talents.can_buy("quick_hands"),
		"past the milestone, the node is STILL refused without its prerequisite")
	GameState.talents = {"marksman": 2}
	_check(Talents.can_buy("quick_hands"),
		"milestone reached and prerequisite met, the tier-2 node opens")
	# Role nodes train ONE member: the gunner's node does nothing to the leader.
	var leader_dmg := leader.damage_mult
	Talents.apply_rank(leader, "leader", "suppressor")
	_check(is_equal_approx(leader.damage_mult, leader_dmg),
		"a gunner-tagged node skips the leader")

	# 6. Progression persists through the save (scratch slot; the world boot
	#    flagged this run as a debug session — lift that for the write).
	const TEST_SLOT := 9
	GameState.debug_session = false
	_check(GameState.save_game("skirmish", TEST_SLOT), "progression save writes")
	var xp_saved := GameState.xp
	GameState.xp = 0
	GameState.talents = {}
	GameState.cleared_sites = []
	var lvl_saved := GameState.crew_level
	GameState.crew_level = 1
	GameState.load_game(TEST_SLOT)
	_check(GameState.xp == xp_saved and GameState.crew_level == lvl_saved
		and Talents.ranks_in("marksman") == 2
		and GameState.cleared_sites.has("skirmish"),
		"save round-trips xp/level/talents/cleared")
	DirAccess.remove_absolute(SaveManager._path(TEST_SLOT))
	GameState.debug_session = true

	# 7. The KIT: ability nodes hand out verbs, and the verbs actually work.
	#    Each one is checked by its EFFECT, not by "activate returned true" —
	#    an ability that reports success and changes nothing is the bug.
	GameState.crew_level = int(Talents.TIER_LEVEL[5])
	GameState.talents = {"quick_hands": 1, "smoke_screen": 1, "focus_fire": 1,
		"combat_stim": 1, "emp_charge": 1}
	var kit_before := leader.action_slots.size()
	for id in ["smoke_screen", "focus_fire", "combat_stim", "emp_charge"]:
		Talents.apply_rank(leader, "leader", str(id))
	_check(leader.action_slots.size() == kit_before + 4,
		"four ability nodes put four verbs in the kit (%d → %d)"
		% [kit_before, leader.action_slots.size()])
	_check(leader.action_slots.size() <= Character.MAX_ACTION_SLOTS,
		"the kit never overflows its slot cap")

	# Smoke: a real COVER-layer volume that blinds the AI too.
	var smoke_before := get_tree().get_nodes_in_group("cover").size()
	var here := leader.global_position
	# Throw it far enough out that the probe ray STARTS outside the cloud —
	# Godot reports no hit for a ray originating inside a shape.
	_check(Talents.SMOKE.activate(leader, here + Vector3(6, 0, 0)), "smoke throws")
	await _settle(3)
	var blocked: Dictionary = _world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(here + Vector3(0, 1.2, 0),
			here + Vector3(11, 1.2, 0), Layers.COVER))
	_check(not blocked.is_empty(), "the cloud genuinely blocks line of sight")

	# Stim: heals HP, which nothing else in a fight does.
	leader.hp = leader.max_hp * 0.4
	var hurt := leader.hp
	_check(Talents.STIM.activate(leader, here), "the stim fires")
	_check(leader.hp > hurt, "the stim heals (%.0f → %.0f)" % [hurt, leader.hp])
	_check(leader.effect_speed_mult() > 1.0, "and it speeds the crew up")

	# Focus Fire: a command, so it needs a target and it moves the FOLLOWERS.
	_check(not Talents.FOCUS.activate(leader, here + Vector3(2, 0, 0)),
		"focus fire refuses when nothing is under the cursor")

	# Light Step is a permanent multiplier, not a timed one.
	var speed_before := leader.base_speed_mult
	Talents.apply_rank(leader, "leader", "light_step")
	_check(leader.base_speed_mult > speed_before,
		"Light Step raises base movement speed")

	if _failures.is_empty():
		print("DISTRICT_PROGRESSION_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_PROGRESSION_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
