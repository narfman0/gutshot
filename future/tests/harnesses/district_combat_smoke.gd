## Headless district combat smoke — run with:
##   godot --headless res://future/tests/harnesses/district_combat_smoke.tscn
## Ports the per-site combat assertions into the seamless world: exchange
## multi-floor sites drawn whole at their district offset,
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

	# 2. Multi-floor sites are drawn WHOLE, always. The reveal/translucency
	#    system is gone (playtest 2026-08-15): upper floors used to fade out
	#    so the iso camera could see in, which read as missing geometry at
	#    eye level in OTS and as flicker in iso. Nothing may quietly start
	#    hiding geometry again.
	var exchange := _chunk("Exchange")
	leader.global_position = exchange.to_global(Vector3(0, 0.1, 12))
	await _settle(10)
	var faded := 0
	var checked := 0
	for node in exchange.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g == null or not is_instance_valid(g):
			continue
		checked += 1
		if g.transparency > 0.01 or not g.visible:
			faded += 1
	_check(checked > 0, "the Exchange has geometry to check (%d)" % checked)
	_check(faded == 0,
		"every floor of the Exchange is drawn solid (%d of %d faded)" % [faded, checked])
	# And from up on the gallery, the floors below stay drawn too.
	leader.global_position = exchange.to_global(Vector3(-26, 3.05, -5))
	await _settle(10)
	faded = 0
	for node in exchange.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g != null and is_instance_valid(g) and (g.transparency > 0.01 or not g.visible):
			faded += 1
	_check(faded == 0, "climbing to the gallery fades nothing (%d faded)" % faded)

	# 3. Depot breach: doors closed force the catwalk detour; blowing one and
	#    awaiting the THREADED rebake opens the short route.
	var depot := _chunk("Depot")
	var map := _world.get_world_3d().navigation_map
	var front := depot.to_global(Vector3(-8.0, 0.1, 4.0))
	var back := depot.to_global(Vector3(-8.0, 0.1, -12.0))
	var before := _path_length(map, front, back)
	_check(before > 25.0, "doors closed: yard→backroom detours (%.1f m)" % before)
	# Depot's doors only — the tower's Level 4 seal shares the group now.
	var depot_bounds := depot.bounds_rect()
	var doors: Array = []
	for node in get_tree().get_nodes_in_group("breach_doors"):
		var pos: Vector3 = (node as Node3D).global_position
		if depot_bounds.has_point(Vector2(pos.x, pos.z)):
			doors.append(node)
	_check(doors.size() == 2, "two depot breach doors stand (got %d)" % doors.size())
	doors.sort_custom(func(a, b):
		return (a as Node3D).global_position.x < (b as Node3D).global_position.x)
	var door := doors[0] as BreachDoor  # the western door (front/back test route)
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

	# 6. Patrols WALK THEIR ROUTE and hold each post. Unpatrolled turf-holders
	#    stay put, which is the point: a gang holds a corner, it doesn't march.
	Factions.reset_provocations()
	var walker: EnemyController = null
	for node in get_tree().get_nodes_in_group("pack_skirmish:east"):
		var ec := node as EnemyController
		if ec != null and not ec.patrol_points.is_empty():
			walker = ec
	_check(walker != null, "the street's east pack has a unit on a beat")
	if walker != null and is_instance_valid(walker.body):
		# Keep the crew far away so nothing drags the patrol into a fight.
		leader.global_position = _chunk("Hideout").to_global(Vector3(0, 0.1, 4))
		await _settle(5)
		var start_pos := walker.body.global_position
		var moved := 0.0
		var dwelled := false
		for k in 30:
			await get_tree().create_timer(0.5).timeout
			if not is_instance_valid(walker.body) or not walker.body.is_alive():
				break
			moved = maxf(moved, start_pos.distance_to(walker.body.global_position))
			if walker.state == EnemyController.State.IDLE \
					and walker.body.velocity.length() < 0.2 and moved > 1.0:
				dwelled = true
		_check(moved > 3.0, "the patrol actually walks its route (%.1f m)" % moved)
		_check(dwelled, "the patrol HOLDS a post rather than marching nonstop")
		# Coming off a chase, it resumes at the nearest post, not the abandoned one.
		walker.body.global_position = _chunk("Street").to_global(
			walker.patrol_points[0] as Vector3)
		walker._resume_patrol()
		_check(walker._patrol_index == 0,
			"a patrol resumes at the NEAREST post (index %d)" % walker._patrol_index)

	if _failures.is_empty():
		print("DISTRICT_COMBAT_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_COMBAT_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
