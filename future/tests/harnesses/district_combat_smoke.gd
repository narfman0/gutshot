## Headless district combat smoke — run with:
##   godot --headless res://future/tests/harnesses/district_combat_smoke.tscn
## Ports the per-site combat assertions into the seamless world: exchange
## FloorSystem at its district offset (solid from outside, reveal inside),
## depot breach door + THREADED navmesh rebake, depot morale break, fab
## sanctum trespass provocation, and site-prefixed pack groups.
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

func _path_length(map: RID, from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total

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
		print("DISTRICT_COMBAT_SMOKE: 1 FAILURES")
		get_tree().quit(1)
		return
	_world.respawn_delay = 9999.0  # respawn cycle is its own smoke
	var leader := GameState.squad[0] as Character

	# 1. Pack groups are site-prefixed.
	_check(get_tree().get_nodes_in_group("pack_depot:back").size() == 3,
		"depot back pack registers under its site-prefixed group")

	# 2. Exchange FloorSystem at the district offset: building solid from
	#    outside, reveal state engages inside, gallery commits on the climb.
	var exchange := _chunk("Exchange")
	var fs := _world.get_node("FloorSystem_exchange") as FloorSystem
	_check(fs != null, "exchange gets a FloorSystem")
	_check(fs.opacity(1) == 1.0 and fs.opacity(2) == 1.0,
		"from outside the Exchange stands whole (%.2f/%.2f)" % [fs.opacity(1), fs.opacity(2)])
	leader.global_position = exchange.to_global(Vector3(0, 0.1, 20))
	await _settle(40)
	_check(fs.active_floor == 0 and fs.opacity(1) < 0.05,
		"inside on the ground floor the gallery hides (floor %d, %.2f)"
		% [fs.active_floor, fs.opacity(1)])
	leader.global_position = exchange.to_global(Vector3(-26, 3.05, -5))
	await _settle(40)
	_check(fs.active_floor == 1 and fs.opacity(1) > 0.95,
		"climbing commits the gallery floor (floor %d, %.2f)"
		% [fs.active_floor, fs.opacity(1)])
	leader.global_position = _chunk("Hideout").to_global(Vector3(0, 0.1, 4))
	await _settle(40)
	_check(fs.opacity(1) == 1.0, "leaving the Exchange re-solidifies it")

	# 3. Depot breach: doors closed force the catwalk detour; blowing one and
	#    awaiting the THREADED rebake opens the short route.
	var depot := _chunk("Depot")
	var map := _world.get_world_3d().navigation_map
	var front := depot.to_global(Vector3(-8.0, 0.1, 4.0))
	var back := depot.to_global(Vector3(-8.0, 0.1, -12.0))
	var before := _path_length(map, front, back)
	_check(before > 25.0, "doors closed: yard→backroom detours (%.1f m)" % before)
	var doors := get_tree().get_nodes_in_group("breach_doors")
	_check(doors.size() == 2, "two breach doors stand (got %d)" % doors.size())
	var door := doors[0] as BreachDoor
	while is_instance_valid(door) and door.hp > 0.0:
		door.receive_damage(40.0)
	var after := before
	for i in 900:  # threaded district rebake — poll up to ~15 s
		await get_tree().physics_frame
		after = _path_length(map, front, back)
		if after < before - 8.0:
			break
	_check(after < before - 8.0,
		"breach + threaded rebake opens the short route (%.1f → %.1f m)" % [before, after])

	# 4. Depot morale: cut the 3-strong back pack to one — the survivor breaks.
	var back_pack := get_tree().get_nodes_in_group("pack_depot:back")
	if back_pack.size() == 3:
		var survivor := back_pack[2] as EnemyController
		(back_pack[0] as EnemyController).body.receive_damage(9999.0)
		(back_pack[1] as EnemyController).body.receive_damage(9999.0)
		await get_tree().physics_frame
		_check(survivor.state == EnemyController.State.FLEE,
			"last bandit standing breaks and runs (state %d)" % survivor.state)
	else:
		_check(false, "back pack missing for the morale test")

	# 5. Fab sanctum trespass: overstay the grace and the Assembly turns.
	Factions.reset_provocations()
	var fab := _chunk("Fab")
	leader.global_position = fab.to_global(Vector3(0, 0.1, -12))
	await get_tree().create_timer(7.5).timeout
	_check(Factions.hostile(Factions.CREW, Factions.ASSEMBLY),
		"sanctum overstay provokes the Assembly")

	if _failures.is_empty():
		print("DISTRICT_COMBAT_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_COMBAT_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
