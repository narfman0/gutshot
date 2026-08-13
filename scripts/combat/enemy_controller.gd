## Enemy controller — the awareness wrapper over the shared CombatBrain.
##
##   IDLE        ambling near spawn; watching for movement in sight range
##   SUSPICIOUS  heard gunfire / lost a track — walks to the point, looks
##               around for a beat, goes back to IDLE if nothing's there
##   FIGHT       the brain owns it: cover, pop-out bursts, flanks, LKP aiming
##
## Being shot at always jumps straight to FIGHT with the shooter pinned
## (muzzle flash = position fix). Pack-mates share alerts: a spotter drags
## the whole pack in, with the spotted position seeded as everyone's LKP.
class_name EnemyController
extends Node

const GRAVITY := 9.8
const WANDER_RADIUS := 5.0        # amble this far around spawn while idle
const WANDER_PAUSE_SECS := 2.5    # stand a beat between ambles
const SUSPICIOUS_LINGER_SECS := 4.0  # look around at the noise point this long
const INVESTIGATE_SPEED := 3.5    # slower than combat speed — wary, not charging

enum State { IDLE, SUSPICIOUS, FIGHT }

@export var aggro_radius := 12.0  # sight range while not in a fight
## Enemies sharing a pack_id aggro together the moment one of them does.
@export var pack_id := ""
@export var leash_radius := 25.0

var body: Character
var brain: CombatBrain
var state: State = State.IDLE

var _investigate := Vector3.INF
var _linger := 0.0
var _wander_target := Vector3.INF
var _wander_pause := 0.0
var _spawn := Vector3.ZERO

func _ready() -> void:
	body = get_parent() as Character
	brain = body.get_node("CombatBrain")
	brain.leash_radius = leash_radius
	_spawn = body.global_position
	if pack_id != "":
		add_to_group("pack_" + pack_id)
	body.character_died.connect(func(_c):
		set_physics_process(false)
		# A pack-mate going down is an alert all by itself.
		if pack_id != "":
			for member in get_tree().get_nodes_in_group("pack_" + pack_id):
				if member != self and member is EnemyController:
					(member as EnemyController).alerted(body.global_position))
	# Being fired at — hit OR miss, any distance — always draws return fire:
	# the muzzle flash reveals exactly who shot, so pin them as the threat.
	body.shot_at.connect(func(attacker: Character):
		brain.pin_threat(attacker)
		_enter_fight())

func _physics_process(delta: float) -> void:
	if body == null or not body.is_alive():
		return
	match state:
		State.IDLE:
			_tick_idle(delta)
		State.SUSPICIOUS:
			_tick_suspicious(delta)
		State.FIGHT:
			_tick_fight(delta)

# ── Alerts ───────────────────────────────────────────────────────────────────

## Gunfire in earshot: go look at where the noise came from (no target yet).
func heard(noise_pos: Vector3) -> void:
	if state == State.FIGHT or not body.is_alive():
		return
	state = State.SUSPICIOUS
	_investigate = noise_pos
	_linger = SUSPICIOUS_LINGER_SECS

## Pack broadcast: a mate spotted trouble at `where`. Fight if we can find a
## target ourselves, otherwise move in on the shared position fix.
func alerted(where: Vector3 = Vector3.INF) -> void:
	if state == State.FIGHT or not body.is_alive():
		return
	if brain.acquire_threat() != null:
		_enter_fight()
	elif where != Vector3.INF:
		heard(where)

func _enter_fight() -> void:
	if state == State.FIGHT:
		return
	state = State.FIGHT
	# Drag the pack along, sharing the position fix we have.
	if pack_id != "":
		var fix := brain.threat_pos() if brain.threat != null else Vector3.INF
		for member in get_tree().get_nodes_in_group("pack_" + pack_id):
			if member != self and member is EnemyController:
				(member as EnemyController).alerted(fix)

# ── States ───────────────────────────────────────────────────────────────────

func _tick_idle(delta: float) -> void:
	if _check_sight():
		return
	# Amble: short walks around the spawn point with pauses between.
	if _wander_target == Vector3.INF:
		_wander_pause -= delta
		_stand(delta)
		if _wander_pause <= 0.0:
			var ang := randf() * TAU
			_wander_target = _spawn + Vector3(cos(ang), 0, sin(ang)) * randf_range(1.5, WANDER_RADIUS)
		return
	if not brain.nav_to(_wander_target, delta, INVESTIGATE_SPEED):
		_wander_target = Vector3.INF
		_wander_pause = WANDER_PAUSE_SECS * randf_range(0.6, 1.6)

func _tick_suspicious(delta: float) -> void:
	if _check_sight():
		return
	if _investigate != Vector3.INF:
		if not brain.nav_to(_investigate, delta, INVESTIGATE_SPEED):
			_investigate = Vector3.INF  # arrived (or unreachable) — look around
		return
	_stand(delta)
	_linger -= delta
	if _linger <= 0.0:
		state = State.IDLE
		_wander_target = Vector3.INF
		_wander_pause = 0.5

func _tick_fight(delta: float) -> void:
	brain.tick(delta)
	# The brain lost the track — go poke at the last-known position.
	if brain.lost_lkp != Vector3.INF:
		var lkp := brain.lost_lkp
		brain.lost_lkp = Vector3.INF
		state = State.SUSPICIOUS
		_investigate = lkp
		_linger = SUSPICIOUS_LINGER_SECS

## A player-team character visible inside sight range → fight, tell the pack.
func _check_sight() -> bool:
	for node in get_tree().get_nodes_in_group("team_%d" % (1 - body.team)):
		var c := node as Character
		if c == null or not c.is_alive():
			continue
		if body.global_position.distance_to(c.global_position) > aggro_radius:
			continue
		if Cover.exposure(body.muzzle_position(), c) > Cover.FULL_COVER_MAX:
			brain.pin_threat(c)
			_enter_fight()
			return true
	return false

func _stand(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= GRAVITY * delta
	body.velocity.x = 0.0
	body.velocity.z = 0.0
	body.move_and_slide()
