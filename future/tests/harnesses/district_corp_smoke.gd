## Headless corp-security smoke — run with:
##   godot --headless res://future/tests/harnesses/district_corp_smoke.tscn
## Vantag Security: neutral lobby (walk in freely), the shield-mender tops
## up drained pack mates, bounding-overwatch roles split across the pack,
## gunfire in the tower provokes on the second shot, and climbing past the
## rope provokes after the grace.
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

func _pack(name: String) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("pack_tower:" + name):
		if is_instance_valid(node):
			out.append(node)
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
		print("DISTRICT_CORP_SMOKE: 1 FAILURES")
		get_tree().quit(1)
		return
	_world.respawn_delay = 9999.0
	await _settle(15)
	var leader := GameState.squad[0] as Character
	for member in GameState.squad:
		if member != leader:
			((member as Character).get_node("SquadFollow") as SquadFollow).enabled = false
	leader.max_hp = 1000000.0
	leader.hp = leader.max_hp
	var tower := _chunk("Tower")

	# 1. The VESTIBULE is public: walk in (doors, desk), nobody draws.
	leader.global_position = tower.to_global(Vector3(0, 0.1, 18))
	await get_tree().create_timer(2.0).timeout
	_check(not Factions.hostile(Factions.CREW, Factions.CORP),
		"walking the lobby stays neutral")
	var drawn := false
	for node in _pack("lobby"):
		if (node as EnemyController).state == EnemyController.State.FIGHT:
			drawn = true
	_check(not drawn, "the desk detail holds its fire on a neutral crew")

	# 2. Bounding overwatch: the exec pack's roles split — someone always
	#    suppressing, someone always moving.
	var roles: Array = []
	for node in _pack("exec"):
		var ec := node as EnemyController
		if is_instance_valid(ec.body) and ec.body.is_alive() and ec.disciplined:
			roles.append(ec._suppress_role())
	_check(roles.has(true) and roles.has(false),
		"overwatch roles split across the pack (%s)" % [roles])

	# 3. The mender: a drained pack mate gets beamed back up.
	var drained: Character = null
	for node in _pack("exec"):
		var ec := node as EnemyController
		if ec.disciplined and is_instance_valid(ec.body):
			drained = ec.body
			break
	drained.shield = 4.0
	await get_tree().create_timer(4.0).timeout
	_check(drained.shield > 4.0,
		"the mender restores a drained shield (%.0f)" % drained.shield)

	# 4. The metal detector: cross the line armed → alarm and a grace;
	#    back off and it stands down; overstay and they lay in.
	leader.global_position = tower.to_global(Vector3(0, 0.1, 8))
	await get_tree().create_timer(1.2).timeout
	_check(not Factions.hostile(Factions.CREW, Factions.CORP),
		"crossing the detector starts a grace, not a war")
	leader.global_position = tower.to_global(Vector3(0, 0.1, 18))
	await get_tree().create_timer(1.0).timeout
	_check(not Factions.hostile(Factions.CREW, Factions.CORP),
		"backing off across the line stands the alarm down")
	leader.global_position = tower.to_global(Vector3(0, 0.1, 8))
	await get_tree().create_timer(6.5).timeout  # grace 5 s + margin
	_check(Factions.hostile(Factions.CREW, Factions.CORP),
		"overstaying past the detector provokes the detail")
	var responded := false
	for k in 8:
		await get_tree().create_timer(1.0).timeout
		for node in _pack("balcony") + _pack("lobby"):
			if (node as EnemyController).state == EnemyController.State.FIGHT:
				responded = true
		if responded:
			break
	_check(responded, "the detail responds once provoked")

	# 5. Stand down: leave, forgive, let the threat pins expire — then the
	#    gunfire rule. First shot warns, the second draws the room.
	leader.global_position = (_chunk("Street") as Node3D).global_position + Vector3(0, 0.1, 20)
	for k in 4:
		Factions.reset_provocations()
		await get_tree().create_timer(2.5).timeout
		if not Factions.hostile(Factions.CREW, Factions.CORP):
			break
	_check(not Factions.hostile(Factions.CREW, Factions.CORP),
		"grudge clears once the crew backs off")
	# Let the threat pins expire too — walking back in while a guard still
	# has a fix means getting shot, and the DAMAGE would re-provoke.
	var calm := false
	for k in 15:
		await get_tree().create_timer(1.0).timeout
		calm = true
		for node in _pack("lobby") + _pack("balcony") + _pack("exec"):
			if (node as EnemyController).state == EnemyController.State.FIGHT:
				calm = false
		if calm:
			break
	_check(calm, "the detail stands down once the crew is gone")
	Factions.reset_provocations()  # in case a parting shot re-provoked
	leader.global_position = tower.to_global(Vector3(0, 0.1, 18))
	await _settle(5)
	var shooter: Shooter = leader.get_node("Shooter")
	shooter.fire_wild(tower.to_global(Vector3(0, 0.0, -5)))
	await get_tree().create_timer(0.5).timeout
	_check(not Factions.hostile(Factions.CREW, Factions.CORP),
		"one shot in the lobby is a warning, not a war")
	shooter.fire_wild(tower.to_global(Vector3(0, 0.0, -5)))
	await get_tree().create_timer(0.5).timeout
	_check(Factions.hostile(Factions.CREW, Factions.CORP),
		"the second shot provokes Vantag Security")

	if _failures.is_empty():
		print("DISTRICT_CORP_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_CORP_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)