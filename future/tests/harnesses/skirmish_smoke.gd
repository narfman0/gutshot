## Headless skirmish smoke — run with:
##   godot --headless res://future/tests/harnesses/skirmish_smoke.tscn
## Boots the real mission scene twice: once killing every enemy to assert
## mission_complete, once wiping the squad to assert mission_failed. Also
## sanity-checks the baked navmesh and the debug-squad fallback.
extends Node

var _failures: Array[String] = []
# Signal outcome flags as instance vars: GDScript lambdas capture locals by
# value, so a `var completed` flipped inside a connect() lambda stays false
# out here.
var _completed := false
var _mission_failed := false

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _boot_world() -> GameWorld:
	GameState.squad = []
	GameState.debug_session = false
	var world: GameWorld = load("res://scenes/levels/skirmish.tscn").instantiate()
	add_child(world)
	# GameWorld._ready awaits physics frames before baking; give it time.
	for i in 10:
		await get_tree().physics_frame
	return world

func _ready() -> void:
	# ── Phase 1: victory path ────────────────────────────────────────────────
	var world := await _boot_world()
	_check(GameState.debug_session, "standalone boot spawns the debug squad")
	_check(GameState.squad.size() == 4, "4 crew spawned")
	var enemies := get_tree().get_nodes_in_group("team_1")
	_check(enemies.size() == 7, "7 enemies spawned (got %d)" % enemies.size())
	var map := world.get_world_3d().navigation_map
	var on_mesh := NavigationServer3D.map_get_closest_point(map, Vector3(5, 0, 5))
	_check(on_mesh.distance_to(Vector3(5, 0, 5)) < 1.5,
		"navmesh covers the arena (closest %s)" % on_mesh)
	(world.get_node("ObjectiveManager") as ObjectiveManager).mission_complete.connect(
		func(): _completed = true)
	for enemy in enemies:
		(enemy as Character).receive_damage(9999.0)
	await get_tree().physics_frame
	_check(_completed, "killing all enemies fires mission_complete")
	world.free()
	await get_tree().physics_frame

	# ── Phase 2: defeat path ─────────────────────────────────────────────────
	world = await _boot_world()
	(world.get_node("ObjectiveManager") as ObjectiveManager).mission_failed.connect(
		func(): _mission_failed = true)
	for member in GameState.squad:
		(member as Character).receive_damage(9999.0)
	await get_tree().physics_frame
	_check(_mission_failed, "wiping the squad fires mission_failed")
	world.free()

	if _failures.is_empty():
		print("SKIRMISH_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("SKIRMISH_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
