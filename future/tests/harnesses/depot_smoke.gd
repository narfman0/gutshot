## Headless Depot 9 smoke — run with:
##   godot --headless res://future/tests/harnesses/depot_smoke.tscn
## Asserts the Phase-2 systems on the real level: catwalk elevation is
## navigable, the dividing wall blocks direct paths until a breach door is
## destroyed (navmesh re-bake opens the way), and bandit morale breaks when
## a pack is cut down.
extends Node

var _failures: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _path_between(map: RID, from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(map, from, to, true)

func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	var world: GameWorld = load("res://scenes/levels/depot.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().physics_frame
	_check(GameState.squad.size() == 4, "crew spawned in the depot")
	var map := world.get_world_3d().navigation_map

	# 1. Catwalk elevation: a path from the yard onto the deck exists and ends
	#    at deck height.
	var deck := Vector3(0, world.DECK_H, -4.0)
	var to_deck := _path_between(map, Vector3(0, 0, 15), deck)
	_check(to_deck.size() > 1 and to_deck[to_deck.size() - 1].y > 1.5,
		"catwalk is navigable from the yard (path %d pts, end y %.1f)"
		% [to_deck.size(), to_deck[to_deck.size() - 1].y if to_deck.size() > 0 else -1.0])

	# 2. Breach: the direct yard→backroom route must funnel over the catwalk
	#    while doors stand (long path); blowing a door opens the short way.
	var front := Vector3(-8.0, 0.1, 4.0)
	var back := Vector3(-8.0, 0.1, -12.0)
	var before := _path_length(_path_between(map, front, back))
	_check(before > 25.0,
		"doors closed: yard→backroom detours over the catwalk (%.1f m)" % before)
	var doors := get_tree().get_nodes_in_group("breach_doors")
	_check(doors.size() == 2, "two breach doors stand (got %d)" % doors.size())
	var door := doors[0] as BreachDoor  # the x=-8 door (built first)
	var breached := [false]
	door.breached.connect(func(): breached[0] = true)
	while is_instance_valid(door) and door.hp > 0.0:
		door.receive_damage(40.0)
	await get_tree().create_timer(0.5).timeout  # queue_free + deferred rebake
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(breached[0], "door emits breached at 0 hp")
	var after := _path_length(_path_between(map, front, back))
	_check(after < before - 8.0,
		"breach opens the short route (%.1f m -> %.1f m)" % [before, after])

	# 3. Morale: cut the 3-strong back pack to one — the survivor breaks.
	var back_pack: Array = []
	for node in get_tree().get_nodes_in_group("pack_back"):
		back_pack.append(node)
	_check(back_pack.size() == 3, "back pack has 3 members (got %d)" % back_pack.size())
	if back_pack.size() == 3:
		var survivor := back_pack[2] as EnemyController
		(back_pack[0] as EnemyController).body.receive_damage(9999.0)
		(back_pack[1] as EnemyController).body.receive_damage(9999.0)
		await get_tree().physics_frame
		_check(survivor.state == EnemyController.State.FLEE,
			"last bandit standing breaks and runs (state %d)" % survivor.state)

	if _failures.is_empty():
		print("DEPOT_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DEPOT_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
