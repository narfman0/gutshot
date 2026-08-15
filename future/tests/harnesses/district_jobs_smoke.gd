## Headless jobs smoke — run with:
##   godot --headless res://future/tests/harnesses/district_jobs_smoke.tscn
## The retrieval contract end to end: the board hands out one job at a time,
## the loot sits in the target interior, only the ACTIVE character can lift
## it, lifting puts the owner's nearby people onto the carrier, the hideout
## is the only place that banks it, abandoning puts it back — and a clan job
## leaves an honor grudge that resting does NOT forgive.
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

func _loot() -> JobLoot:
	for node in _world.find_children("JobLoot", "", true, false):
		if node is JobLoot:
			return node as JobLoot
	return null

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
	Factions.reset_all()
	_world = load("res://scenes/district.tscn").instantiate()
	add_child(_world)
	for i in 600:
		await get_tree().physics_frame
		if GameState.squad.size() == 4:
			break
	if GameState.squad.size() != 4:
		printerr("FAIL: crew never spawned — world boot broken")
		print("DISTRICT_JOBS_SMOKE: 1 FAILURES")
		get_tree().quit(1)
		return
	_world.respawn_delay = 9999.0
	await _settle(15)
	var leader := GameState.squad[0] as Character
	# The carrier walks through gang turf on purpose; a downed leader stops
	# being the active character and the job would stall on a technicality.
	leader.max_hp = 1000000.0
	leader.hp = leader.max_hp

	# 1. The board hands out ONE contract at a time.
	_check(Jobs.available().size() == Jobs.CATALOG.size(),
		"every contract is on offer at the start (%d)" % Jobs.available().size())
	_check(GameState.accept_job("ledger"), "the crew can take the chop shop job")
	_check(not GameState.accept_job("manifest"),
		"a second contract is refused while one is live")
	_world.refresh_job_loot()
	await _settle(3)

	# 2. The loot is really there, inside the chop shop, and only the ACTIVE
	#    character can lift it (followers blunder through doorways constantly).
	var loot := _loot()
	_check(loot != null, "the loot spawned in the world")
	if loot != null:
		var street := _chunk("Street")
		var want := street.to_global(Jobs.job("ledger")["pos"] as Vector3)
		_check(loot.global_position.distance_to(want) < 2.0,
			"the loot sits in the chop shop (%.1f m off)"
			% loot.global_position.distance_to(want))
		var follower := GameState.squad[1] as Character
		follower.global_position = loot.global_position
		await _settle(5)
		_check(not GameState.carrying, "a follower walking over it does NOT start the job")

	# 3. Lifting it. NOTE the gangs are BASE-hostile to the crew, so there is
	#    no "you made a new enemy" beat on a gang job — the escalation is the
	#    HUNT (step 4). The new-enemy beat belongs to neutral owners, which
	#    the clan job in step 6 covers.
	leader.global_position = _loot().global_position if _loot() != null else leader.global_position
	for i in 40:
		await get_tree().physics_frame
		if GameState.carrying:
			break
	_check(GameState.carrying, "the active character lifts the loot")
	await _settle(3)  # queue_free lands at end of frame
	_check(_loot() == null, "the pickup is consumed")

	# 4. The word goes out: the owner's nearby people get put onto the carrier.
	var hunted := false
	for k in 12:
		await get_tree().create_timer(1.0).timeout
		for node in get_tree().get_nodes_in_group("enemy_ai"):
			var ec := node as EnemyController
			if ec == null or not is_instance_valid(ec.body) or not ec.body.is_alive():
				continue
			if ec.body.team == Factions.GANGS and ec.state == EnemyController.State.FIGHT:
				hunted = true
		if hunted:
			break
	_check(hunted, "the gangs hunt the carrier while the take is out")

	# 5. Only the hideout banks it. Standing in another site does nothing.
	var xp_before := GameState.xp
	leader.global_position = _chunk("Depot").to_global(Vector3(0, 0.1, 6))
	await _settle(10)
	_check(GameState.carrying and GameState.xp == xp_before,
		"walking into another site does not bank the job")
	leader.global_position = _chunk("Hideout").to_global(Vector3(0, 0.1, 4))
	await _settle(10)
	_check(not GameState.carrying, "reaching the hideout banks the take")
	_check(GameState.active_job == "", "the contract closes on delivery")
	_check(GameState.completed_jobs.has("ledger"), "the job is remembered as done")
	_check(GameState.xp == xp_before + int(Jobs.job("ledger")["xp"]),
		"delivery pays the contract (xp %d, expected %d)"
		% [GameState.xp, xp_before + int(Jobs.job("ledger")["xp"])])
	_check(not Jobs.available().has("ledger"), "the board stops offering a finished job")

	# 6. The clan job leaves an HONOR grudge that resting never washes off.
	_check(GameState.accept_job("blade"), "the crew can take the clan job next")
	_world.refresh_job_loot()
	await _settle(3)
	var blade := _loot()
	_check(blade != null, "the clan loot spawned")
	if blade != null:
		leader.global_position = blade.global_position
		for i in 40:
			await get_tree().physics_frame
			if GameState.carrying:
				break
	_check(GameState.carrying, "the crew lifts the blade")
	_check(Factions.hostile(Factions.CLAN, Factions.CREW), "the clan turns on the crew")
	leader.global_position = _chunk("Hideout").to_global(Vector3(0, 0.1, 4))
	await _settle(10)
	_check(not GameState.carrying, "the blade banks at the hideout")
	_check(Factions.hostile(Factions.CLAN, Factions.CREW),
		"the clan does NOT forgive — honor outlives the rest")

	# 7. Abandoning a contract puts the loot back and clears the order.
	_check(GameState.accept_job("manifest"), "the crew takes the depot job")
	_world.refresh_job_loot()
	await _settle(3)
	_check(_loot() != null, "the manifest is on the floor")
	GameState.abandon_job()
	_world.refresh_job_loot()
	await _settle(3)
	_check(_loot() == null and GameState.active_job == "",
		"abandoning clears the order and takes the loot away")
	_check(Jobs.available().has("manifest"), "an abandoned job goes back on the board")

	# 8. Progression survives the save (scratch slot).
	const TEST_SLOT := 9
	GameState.debug_session = false
	_check(GameState.accept_job("manifest"), "re-take the depot job for the save test")
	_check(GameState.save_game("depot", TEST_SLOT), "job state saves")
	GameState.active_job = ""
	GameState.completed_jobs = []
	GameState.load_game(TEST_SLOT)
	_check(GameState.active_job == "manifest"
		and GameState.completed_jobs.has("ledger")
		and GameState.completed_jobs.has("blade"),
		"the save round-trips the live contract and the finished ones")
	DirAccess.remove_absolute(SaveManager._path(TEST_SLOT))
	GameState.debug_session = true

	if _failures.is_empty():
		print("DISTRICT_JOBS_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_JOBS_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
