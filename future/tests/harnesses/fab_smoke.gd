## Headless Fab Level smoke — run with:
##   godot --headless res://future/tests/harnesses/fab_smoke.tscn
## The faction sandbox: machines spawn NEUTRAL (no heat, no fights), the
## bandit salvage crew is the whole objective, and damaging a machine
## provokes the Assembly into the fight.
extends Node

var _failures: Array[String] = []
var _completed := false

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _machine_controllers() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		var controller := node as EnemyController
		if controller != null and controller.body.team == Factions.ASSEMBLY:
			out.append(controller)
	return out

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	var world: GameWorld = load("res://scenes/levels/fab.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().physics_frame

	# 1. Neutral start: machines idle, no crew-Assembly hostility.
	_check(not Factions.hostile(Factions.CREW, Factions.ASSEMBLY),
		"Assembly starts neutral to the crew")
	var machines := _machine_controllers()
	_check(machines.size() == 3, "three machines on the floor (got %d)" % machines.size())
	var salvage := get_tree().get_nodes_in_group("pack_salvage")
	_check(salvage.size() == 3, "bandit salvage crew present (got %d)" % salvage.size())

	# 2. Give the sim a moment: patrolling machines must NOT pick fights.
	await get_tree().create_timer(2.0).timeout
	for controller in machines:
		_check((controller as EnemyController).state != EnemyController.State.FIGHT,
			"neutral machine stays out of fights (state %d)" % (controller as EnemyController).state)

	# 3. The mission is the bandits — machines don't gate completion.
	(world.get_node("ObjectiveManager") as ObjectiveManager).mission_complete.connect(
		func(): _completed = true)
	for node in salvage:
		(node as EnemyController).body.receive_damage(9999.0)
	await get_tree().physics_frame
	_check(_completed, "clearing the salvage crew completes the mission")
	for controller in machines:
		_check((controller as EnemyController).body.is_alive(), "machines untouched by the objective")

	# 4. Provocation: hurt a machine and the Assembly is in it.
	var victim := (machines[0] as EnemyController).body as Character
	var leader := GameState.squad[0] as Character
	victim.receive_damage(10.0, leader)
	await get_tree().physics_frame
	_check(Factions.hostile(Factions.CREW, Factions.ASSEMBLY),
		"damaging a machine provokes the Assembly")
	await get_tree().create_timer(0.5).timeout
	var any_fighting := false
	for controller in machines:
		if (controller as EnemyController).state == EnemyController.State.FIGHT:
			any_fighting = true
	_check(any_fighting, "provoked machines fight back")
	world.free()

	if _failures.is_empty():
		print("FAB_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("FAB_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
