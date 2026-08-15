## Headless pursuit + turf-law smoke — run with:
##   godot --headless res://future/tests/harnesses/district_pursuit_smoke.tscn
## The connector-gameplay promise: fighting packs chase the crew OUT of
## their site and through the corridors; defensive packs hold their ground;
## and gunfire in the Assembly's guard ring turns the machines on the
## shooter's faction — including a gang pack baited into shooting there.
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
	for i in 600:
		await get_tree().physics_frame
		if GameState.squad.size() == 4:
			break
	if GameState.squad.size() != 4:
		printerr("FAIL: crew never spawned — world boot broken")
		print("DISTRICT_PURSUIT_SMOKE: 1 FAILURES")
		get_tree().quit(1)
		return
	_world.respawn_delay = 9999.0
	await _settle(15)
	var leader := GameState.squad[0] as Character
	# Park the followers: this smoke choreographs specific shooters, and
	# helpful squadmates gunning down the test subjects ruins the science.
	for member in GameState.squad:
		if member != leader:
			((member as Character).get_node("SquadFollow") as SquadFollow).enabled = false
	# The leader spends this smoke standing in front of guns on purpose —
	# a downed leader can't fire or be re-pinned, so make them a bullet sponge.
	leader.max_hp = 1000000.0
	leader.hp = leader.max_hp

	# 1. Pursuit: pin the street's mid pack on the leader, then retreat into
	#    the alley — the pack should break its spawn leash and follow out of
	#    the site (the crew "fires back while retreating" via re-pins).
	var mid := get_tree().get_nodes_in_group("pack_skirmish:mid")
	_check(mid.size() == 2, "street mid pack present (got %d)" % mid.size())
	leader.global_position = Vector3(0, 0.1, -2)  # in their faces
	await _settle(3)
	for node in mid:
		if is_instance_valid(node):
			(node as EnemyController).body.notify_shot_at(leader)
	leader.global_position = Vector3(-33, 0.1, 15)  # mid-alley, beyond leash
	# What pursuit MEANS: the spawn leash breaks and they cross the site
	# after you. (Deliberately not "they thread one specific gate" — the
	# dressed street has several west exits and a lot of furniture, and
	# that would test pathfinding polish rather than the chase.)
	var chased := false
	for k in 35:
		await get_tree().create_timer(1.0).timeout
		for node in mid:
			if not is_instance_valid(node):
				continue
			var ec := node as EnemyController
			if is_instance_valid(ec.body) and ec.body.is_alive():
				ec.body.notify_shot_at(leader)  # covering fire keeps the track hot
				if ec.body.global_position.x < -20.0 \
						and ec.brain.leash_radius > 100.0:
					chased = true
		if chased:
			break
	_check(chased, "a pursuing pack breaks its leash and crosses the street after the crew")

	# 2. Defensive packs hold: the vault crew guards the take instead.
	leader.global_position = _chunk("Hideout").to_global(Vector3(0, 0.1, 4))
	var vault := get_tree().get_nodes_in_group("pack_exchange:vault")
	_check(vault.size() == 3, "vault pack present (got %d)" % vault.size())
	for k in 8:
		await get_tree().create_timer(1.0).timeout
		for node in vault:
			if not is_instance_valid(node):
				continue
			var ec := node as EnemyController
			if is_instance_valid(ec.body) and ec.body.is_alive():
				ec.body.notify_shot_at(leader)
	var vault_held := true
	var ex_bounds := _chunk("Exchange").bounds_rect().grow(4.0)
	for node in vault:
		if not is_instance_valid(node):
			continue
		var ec := node as EnemyController
		if is_instance_valid(ec.body) and not ex_bounds.has_point(
				Vector2(ec.body.global_position.x, ec.body.global_position.z)):
			vault_held = false
	_check(vault_held, "the vault crew holds the Exchange (pursue: false)")

	# 3. Turf law: a warning shot inside the guard ring does NOT provoke;
	#    sustained fire does.
	Factions.reset_provocations()
	var fab := _chunk("Fab")
	leader.global_position = fab.to_global(Vector3(10, 0.1, -10))  # in the ring, outside the sanctum
	await _settle(5)
	var shooter: Shooter = leader.get_node("Shooter")
	shooter.fire_wild(fab.to_global(Vector3(-10, 0.0, -14)))
	await get_tree().create_timer(0.6).timeout
	_check(not Factions.hostile(Factions.CREW, Factions.ASSEMBLY),
		"one shot in the ring draws a warning, not a war")
	for i in 6:
		shooter.fire_wild(fab.to_global(Vector3(-10, 0.0, -14)))
		await get_tree().create_timer(0.3).timeout
	_check(Factions.hostile(Factions.CREW, Factions.ASSEMBLY),
		"sustained fire in the ring provokes the Assembly")

	# 4. The bait: a gang bandit dragged into a fight inside the ring shoots
	#    at the crew — and becomes the machines' problem.
	Factions.reset_provocations()
	var salvage := get_tree().get_nodes_in_group("pack_fab:salvage")
	_check(salvage.size() == 3, "salvage pack present (got %d)" % salvage.size())
	var bandit := (salvage[0] as EnemyController).body
	bandit.global_position = fab.to_global(Vector3(6, 0.1, -10))
	leader.global_position = fab.to_global(Vector3(-4, 0.1, -8))
	await _settle(3)
	bandit.notify_shot_at(leader)
	var provoked := false
	for k in 20:
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(bandit) and bandit.is_alive():
			bandit.notify_shot_at(leader)  # keep the bandit's blood up
		if Factions.hostile(Factions.GANGS, Factions.ASSEMBLY):
			provoked = true
			break
	_check(provoked, "gang gunfire in the ring turns the machines on the gangs")
	var machines_fight := false
	for k in 12:
		await get_tree().create_timer(1.0).timeout
		for node in get_tree().get_nodes_in_group("pack_fab:assembly"):
			if is_instance_valid(node) \
					and (node as EnemyController).state == EnemyController.State.FIGHT:
				machines_fight = true
		if machines_fight:
			break
	_check(machines_fight, "the Assembly engages — the chasers became the machines' problem")

	if _failures.is_empty():
		print("DISTRICT_PURSUIT_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_PURSUIT_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
