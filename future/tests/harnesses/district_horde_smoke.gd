## Headless horde smoke — run with:
##   godot --headless res://future/tests/harnesses/district_horde_smoke.tscn
## Breach the tower's Level 4 seal remotely and verify the Spawn: waves
## pour out on schedule (24 husks + 2 brutes), the faction is at war with
## everything, the exec detail actually fights the containment failure, and
## the district holds frame budget with 25+ extra bodies live — the
## docs-mandated horde perf check.
extends Node

var _failures: Array[String] = []
var _world: GameWorld

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

func _horde(alive_only := false) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("pack_tower:horde"):
		if not is_instance_valid(node):
			continue
		var ec := node as EnemyController
		if alive_only and (not is_instance_valid(ec.body) or not ec.body.is_alive()):
			continue
		out.append(ec)
	return out

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
		print("DISTRICT_HORDE_SMOKE: 1 FAILURES")
		get_tree().quit(1)
		return
	_world.respawn_delay = 9999.0
	await _settle(15)

	# 1. The faction is at war with everything from the data alone.
	_check(Factions.hostile(Factions.HORDE, Factions.CREW)
		and Factions.hostile(Factions.HORDE, Factions.GANGS)
		and Factions.hostile(Factions.HORDE, Factions.CORP)
		and Factions.hostile(Factions.HORDE, Factions.ASSEMBLY),
		"the Spawn is hostile to every faction")

	# 2. Breach the seal remotely (crew stays home — this is corp's problem).
	var seal: BreachDoor = null
	for node in get_tree().get_nodes_in_group("breach_doors"):
		if (node as Node3D).global_position.y > 6.0:
			seal = node as BreachDoor
	_check(seal != null, "the Level 4 seal stands as a breach door")
	_check(is_equal_approx(seal.hp, 160.0), "the seal is heavier than a depot door")
	while is_instance_valid(seal) and seal.hp > 0.0:
		seal.receive_damage(80.0)

	# 3. The waves pour out on schedule: 24 husks + 2 brutes. Count by
	#    UNIQUE id — the exec detail starts killing husks mid-wave, and the
	#    dead free themselves out of the group.
	var seen := {}
	for k in 44:
		await get_tree().create_timer(0.5).timeout
		for ec in _horde():
			seen[ec.get_instance_id()] = true
		if seen.size() >= 26:
			break
	var spawned := seen.size()
	_check(spawned >= 26, "the full horde spawned (%d/26)" % spawned)
	var brute_found := false
	for ec in _horde():
		if is_instance_valid((ec as EnemyController).body) \
				and (ec as EnemyController).body.max_hp >= 300.0:
			brute_found = true
	_check(brute_found, "a brute walks among them")

	# 4. Perf: 25+ extra bodies live and brawling with the exec detail —
	#    physics frames must keep pace (the 20-40 body check from the docs).
	var t0 := Time.get_ticks_usec()
	var frames := 240
	for i in frames:
		await get_tree().physics_frame
	var avg_ms := float(Time.get_ticks_usec() - t0) / float(frames) / 1000.0
	print("horde perf: %.1f ms avg physics frame with %d horde alive"
		% [avg_ms, _horde(true).size()])
	_check(avg_ms < 25.0, "district holds frame budget under horde load (%.1f ms)" % avg_ms)

	# 5. Containment is real: the exec detail engaged — usually meaning it
	#    has already been ANNIHILATED by 26 adjacent melee bodies (dead
	#    enemies free with their controllers), or it's still fighting, or
	#    it took some of the horde down with it.
	var corp_fighting := false
	var exec_alive := 0
	for node in get_tree().get_nodes_in_group("pack_tower:exec"):
		if not is_instance_valid(node):
			continue
		var ec := node as EnemyController
		if is_instance_valid(ec.body) and ec.body.is_alive():
			exec_alive += 1
			if ec.state == EnemyController.State.FIGHT:
				corp_fighting = true
	var horde_alive := _horde(true).size()
	var detail := ""
	for node in get_tree().get_nodes_in_group("pack_tower:exec"):
		if is_instance_valid(node):
			var ec := node as EnemyController
			if is_instance_valid(ec.body):
				detail += " exec[s%d y%.1f]" % [ec.state, ec.body.global_position.y]
	var h := _horde(true)
	if h.size() > 0:
		var hb := (h[0] as EnemyController)
		detail += " horde0[s%d y%.1f]" % [hb.state, hb.body.global_position.y]
	_check(corp_fighting or exec_alive < 4 or horde_alive < spawned,
		"the containment fight happened (fighting=%s, exec %d/4, horde %d/%d,%s)"
		% [corp_fighting, exec_alive, horde_alive, spawned, detail])

	if _failures.is_empty():
		print("DISTRICT_HORDE_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_HORDE_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
