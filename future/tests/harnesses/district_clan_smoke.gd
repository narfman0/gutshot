## Headless Little Japan / clan smoke — run with:
##   godot --headless res://future/tests/harnesses/district_clan_smoke.tscn
## The clan: silent steel (shurikens raise no alarm), smoke that genuinely
## blocks line of sight, the vanish dash, HONOR grudges that survive a rest
## the way ordinary provocations do not — and a market full of civilians who
## run, plus a gang incursion the clan is already at war with.
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
	for node in get_tree().get_nodes_in_group("pack_littlejapan:" + name):
		if is_instance_valid(node):
			out.append(node)
	return out

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	GameState.start_site = "hideout"
	Factions.reset_all()
	_world = load("res://scenes/district.tscn").instantiate()
	add_child(_world)
	for i in 600:
		await get_tree().physics_frame
		if GameState.squad.size() == 4:
			break
	if GameState.squad.size() != 4:
		printerr("FAIL: crew never spawned — world boot broken")
		print("DISTRICT_CLAN_SMOKE: 1 FAILURES")
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
	var lj := _chunk("Littlejapan")

	# 1. The market is populated: crowd, patrol, roof watch, shrine, gangs.
	_check(_pack("crowd").size() == 5, "the market crowd is there (%d)" % _pack("crowd").size())
	_check(_pack("patrol").size() == 3, "clan patrol walks the alley (%d)" % _pack("patrol").size())
	_check(_pack("roof").size() == 2, "the roof watch is up (%d)" % _pack("roof").size())
	_check(_pack("shrine").size() == 3, "the sensei holds the shrine (%d)" % _pack("shrine").size())
	_check(_pack("shakedown").size() == 4, "gangs are working the stalls (%d)"
		% _pack("shakedown").size())

	# 2. Civilians are unarmed and nobody's enemy; the clan is at war with
	#    the gangs from the first frame.
	var civ := (_pack("crowd")[0] as EnemyController).body
	_check(civ.team == Factions.CIVIL and civ.active_gear() == null,
		"civilians carry nothing")
	_check(not Factions.hostile(Factions.CIVIL, Factions.CREW),
		"civilians are nobody's enemy")
	_check(Factions.hostile(Factions.CLAN, Factions.GANGS),
		"the clan and the gangs are already at it")
	_check(not Factions.hostile(Factions.CLAN, Factions.CREW),
		"the clan tolerates the crew — until it doesn't")

	# 3. Silent steel: a shuriken raises no alarm (no shot_fired at all).
	var thrower: Character = null
	for node in _pack("roof"):
		thrower = (node as EnemyController).body
		break
	var heard := [0]
	GameState.shot_fired.connect(func(_s): heard[0] += 1)
	var ts: Shooter = thrower.get_node("Shooter")
	_check(thrower.active_gear() != null and thrower.active_gear().silent,
		"the roof watch throws silent steel")
	ts.fire_wild(thrower.global_position + Vector3(3, 0, 3))
	await _settle(3)
	_check(heard[0] == 0, "shurikens raise no alarm (%d heard)" % heard[0])

	# 4. Smoke is real cover: LOS between two points is open, then blocked.
	leader.global_position = lj.to_global(Vector3(0, 0.1, 6))
	var mark := GameState.squad[1] as Character
	mark.global_position = lj.to_global(Vector3(0, 0.1, -2))
	await _settle(5)
	var open_before := Cover.exposure(leader.muzzle_position(), mark)
	SmokeBomb.pop(get_tree().current_scene, lj.to_global(Vector3(0, 0.1, 2)))
	await _settle(5)
	var open_after := Cover.exposure(leader.muzzle_position(), mark)
	_check(open_before > Cover.FULL_COVER_MAX and open_after <= Cover.FULL_COVER_MAX,
		"smoke blinds the line (%.2f → %.2f)" % [open_before, open_after])

	# 5. Honor: hurting the clan provokes them LASTINGLY — a hideout rest
	#    forgives the Assembly but never the clan.
	Factions.reset_all()
	Factions.provoke(Factions.CREW, Factions.ASSEMBLY)
	var ninja := (_pack("patrol")[0] as EnemyController).body
	ninja.receive_damage(5.0, leader)
	await _settle(2)
	_check(Factions.hostile(Factions.CREW, Factions.CLAN),
		"drawing clan blood starts a fight")
	_check(Factions.has_honor_grudge(Factions.CREW, Factions.CLAN),
		"...and it is recorded as HONOR, not a mood")
	Factions.reset_provocations()  # what the hideout rest does
	_check(not Factions.hostile(Factions.CREW, Factions.ASSEMBLY),
		"resting forgives the machines")
	_check(Factions.hostile(Factions.CREW, Factions.CLAN),
		"resting does NOT forgive the clan")

	# 6. Vanish: a hurt ninja pops smoke and repositions.
	var vanisher: EnemyController = _pack("patrol")[0]
	var before_pos := vanisher.body.global_position
	leader.global_position = before_pos + Vector3(4, 0, 0)
	await _settle(3)
	vanisher.body.notify_shot_at(leader)
	var smoked := false
	for k in 30:
		await get_tree().physics_frame
		for child in get_tree().current_scene.get_children():
			if child is SmokeBomb:
				smoked = true
		if smoked:
			break
	_check(smoked, "a hurt ninja drops smoke")
	await get_tree().create_timer(2.5).timeout
	_check(vanisher.body.global_position.distance_to(before_pos) > 2.5,
		"...and is not where you left them (%.1f m)"
		% vanisher.body.global_position.distance_to(before_pos))

	if _failures.is_empty():
		print("DISTRICT_CLAN_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("DISTRICT_CLAN_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
