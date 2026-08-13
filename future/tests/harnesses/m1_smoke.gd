## End-to-end M1 smoke — run with:
##   godot --headless res://future/tests/harnesses/m1_smoke.tscn
## Boots the real skirmish, pushes the squad into contact, drives the leader
## with the same CombatBrain the followers use (input can't be scripted
## headless), and runs the whole fight at 4× until one side wins. Asserting a
## terminal state proves movement, cover AI, shooting, and objectives close
## the loop end to end.
extends Node

const BUDGET_SECS := 120.0  # real seconds at 4× = ~8 minutes of fight

var _failures: Array[String] = []
var _ended := false
var _leader_brain: CombatBrain

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	var world: GameWorld = load("res://scenes/levels/skirmish.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().physics_frame
	_check(GameState.squad.size() == 4, "crew spawned")
	GameState.mission_ended.connect(func(_victory): _ended = true)

	# Contact: move the crew to midfield; the leader gets brain-driven.
	var leader: Character = GameState.squad[0]
	for member in GameState.squad:
		(member as Character).global_position += Vector3(0, 0, -10)
	var player: PlayerController = leader.get_node("PlayerController")
	player.enabled = false
	_leader_brain = leader.get_node("CombatBrain")
	_leader_brain.leash_radius = 50.0  # let the whole arena be the fight

	Engine.time_scale = 4.0
	var waited := 0.0
	while not _ended and waited < BUDGET_SECS:
		await get_tree().create_timer(0.5, true, false, true).timeout  # real time
		waited += 0.5
	Engine.time_scale = 1.0
	_check(_ended, "mission reached a terminal state within %.0fs (squad %d vs enemies %d alive)"
		% [BUDGET_SECS, _alive(0), _alive(1)])
	print("m1 result: squad=%d enemies=%d after %.0fs" % [_alive(0), _alive(1), waited])

	if _failures.is_empty():
		print("M1_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("M1_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)

func _physics_process(delta: float) -> void:
	# Drive the leader with the shared brain once the squad is in play; when
	# no threat is in engage range, push toward the nearest survivor the way a
	# player would advance between packs.
	if _leader_brain == null or _ended \
			or not is_instance_valid(_leader_brain.body) or not _leader_brain.body.is_alive():
		return
	if _leader_brain.acquire_threat() != null:
		_leader_brain.tick(delta)
		return
	var body := _leader_brain.body
	var nearest: Character = null
	var best := INF
	for c in get_tree().get_nodes_in_group("team_1"):
		var enemy := c as Character
		if enemy == null or not enemy.is_alive():
			continue
		var d := body.global_position.distance_to(enemy.global_position)
		if d < best:
			best = d
			nearest = enemy
	if nearest != null:
		_leader_brain.nav_to(nearest.global_position, delta)

func _alive(team: int) -> int:
	var count := 0
	for c in get_tree().get_nodes_in_group("team_%d" % team):
		if is_instance_valid(c) and (c as Character).is_alive():
			count += 1
	return count
