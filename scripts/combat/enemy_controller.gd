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

const WANDER_RADIUS := 5.0        # amble this far around spawn while idle
const WANDER_PAUSE_SECS := 2.5    # stand a beat between ambles
## A patrol that never stops reads like a wind-up toy. Guards hold each post
## for a beat and SWEEP their gaze across it before moving on, which is what
## makes a route look like someone doing a job.
const PATROL_DWELL_SECS := 2.2
const PATROL_SWEEP_ARC := 1.5     # radians of look-around at a post
const PATROL_SWEEP_SPEED := 0.9
const SUSPICIOUS_LINGER_SECS := 4.0  # look around at the noise point this long
const INVESTIGATE_SPEED := 3.5    # slower than combat speed — wary, not charging
const MORALE_BREAK_FRAC := 0.5    # pack thinned to half → morale units break
const FLEE_DIST := 14.0           # how far a broken unit runs
const FLEE_RECOVER_SECS := 5.0    # catch breath, then slink back suspicious

enum State { IDLE, SUSPICIOUS, FIGHT, FLEE }

@export var aggro_radius := 12.0  # sight range while not in a fight
## Enemies sharing a pack_id aggro together the moment one of them does.
@export var pack_id := ""
@export var leash_radius := 25.0
## Waypoint loop walked while IDLE (empty → amble near spawn instead).
@export var patrol_points: Array = []
## Morale units (bandits) break and flee when the pack thins to this
## fraction of spawn strength. Space-bandit nerve: their packs default to
## 0.6 via GameWorld's spawner — they crack EARLY, scatter, and slink back.
@export var has_morale := false
@export var morale_break_frac := MORALE_BREAK_FRAC
## Fighting packs with pursue break the spawn leash and chase across the
## seamless district — through corridors, into other sites, into other
## factions' turf. Losing the track ends the chase (they investigate the
## LKP, stand down, and walk home). Defensive packs (a vault crew guarding
## the take, the territorial Assembly) keep the leash instead.
@export var pursue := true
## Corp pack discipline: bounding overwatch. While FIGHTING, half the pack
## SUPPRESSES the last-known position (cadenced bursts, trigger discipline)
## while the other half works the brain's normal cover/flank game; roles
## swap every few seconds. Feels like fighting a mirror of your own squad.
@export var disciplined := false
## Clan doctrine: when hurt, VANISH — smoke at the feet (a real LOS blocker),
## then a fast dash to a flank. The thrower's last-known position goes stale
## the instant the cloud lands, so the crew ends up shooting at where the
## ninja WAS. Weaponizing the awareness system from the other side.
@export var vanisher := false

const VANISH_COOLDOWN := 9.0
const VANISH_DASH := 9.0     # metres of repositioning under the cloud
const VANISH_SPEED := 11.0

const PURSUIT_LEASH := 10000.0  # effectively unleashed while the chase is on
const OVERWATCH_SWAP_SECS := 6.0
const SUPPRESS_BURST := 3
const SUPPRESS_PAUSE_SECS := 0.9
const SUPPORT_RANGE := 11.0     # menders shepherd mates inside this

var body: Character
var brain: CombatBrain
var state: State = State.IDLE

var _investigate := Vector3.INF
var _linger := 0.0
var _wander_target := Vector3.INF
var _wander_pause := 0.0
var _patrol_dwell := 0.0
var _patrol_sweep := 0.0
var _spawn := Vector3.ZERO
var _patrol_index := 0
var _pack_initial := 0
var _flee_timer := 0.0
var _flee_target := Vector3.INF
var _base_leash := 25.0

func _ready() -> void:
	body = get_parent() as Character
	brain = body.get_node("CombatBrain")
	brain.leash_radius = leash_radius
	_base_leash = leash_radius
	_spawn = body.global_position
	add_to_group("enemy_ai")
	if pack_id != "":
		add_to_group("pack_" + pack_id)
	body.character_died.connect(func(_c):
		set_physics_process(false)
		# A pack-mate going down is an alert all by itself — and a morale test.
		if pack_id != "":
			for member in get_tree().get_nodes_in_group("pack_" + pack_id):
				if member != self and member is EnemyController:
					var mate := member as EnemyController
					mate.alerted(body.global_position)
					mate.check_morale())
	# Being fired at — hit OR miss, any distance — always draws return fire:
	# the muzzle flash reveals exactly who shot, so pin them as the threat.
	body.shot_at.connect(func(attacker: Character):
		brain.pin_threat(attacker)
		_enter_fight()
		if vanisher:
			_try_vanish())
	# Count the full pack once everyone has spawned.
	if pack_id != "":
		_count_pack.call_deferred()

func _count_pack() -> void:
	_pack_initial = get_tree().get_nodes_in_group("pack_" + pack_id).size()

func _physics_process(delta: float) -> void:
	if body == null or not body.is_alive():
		return
	# Support units shepherd the pack's shields whenever someone's low —
	# in or out of a fight. Everything else waits.
	if _tick_support(delta):
		return
	# EMP: machines have no morale to break, so a stagger IS their break —
	# a few seconds of standing there doing nothing.
	if body.is_staggered():
		_stand(delta)
		return
	match state:
		State.IDLE:
			_tick_idle(delta)
		State.SUSPICIOUS:
			_tick_suspicious(delta)
		State.FIGHT:
			_tick_fight(delta)
		State.FLEE:
			_tick_flee(delta)

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
	if pursue:
		brain.leash_radius = PURSUIT_LEASH  # the chase is on
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
	# Patrol a waypoint loop if we have one; otherwise amble near spawn.
	if not patrol_points.is_empty():
		_tick_patrol(delta)
		return
	if _wander_target == Vector3.INF:
		_wander_pause -= delta
		_stand(delta)
		if _wander_pause <= 0.0:
			var ang := randf() * TAU
			var candidate := _spawn + Vector3(cos(ang), 0, sin(ang)) \
				* randf_range(1.5, WANDER_RADIUS)
			# Floor-aware wander: a ring point past a deck edge resolves to
			# the floor BELOW, and the guard dutifully abandons his post to
			# reach it. Reject cross-floor rolls; try again next beat.
			var snapped := NavigationServer3D.map_get_closest_point(
				body.get_world_3d().navigation_map, candidate)
			if absf(snapped.y - _spawn.y) <= 1.5:
				_wander_target = snapped
		return
	if not brain.nav_to(_wander_target, delta, INVESTIGATE_SPEED):
		_wander_target = Vector3.INF
		_wander_pause = WANDER_PAUSE_SECS * randf_range(0.6, 1.6)

## Walk the route, then HOLD the post: stand for a beat sweeping the gaze
## across the arc before moving to the next waypoint. The dwell is jittered
## per unit so two guards sharing a route don't march in lockstep.
func _tick_patrol(delta: float) -> void:
	if _patrol_dwell > 0.0:
		_patrol_dwell -= delta
		_patrol_sweep += delta * PATROL_SWEEP_SPEED
		_stand(delta)
		var look := body.global_position + Vector3(
			sin(_patrol_sweep) * PATROL_SWEEP_ARC, 0.0,
			cos(_patrol_sweep) * PATROL_SWEEP_ARC)
		brain.face_point(look)
		return
	var target: Vector3 = patrol_points[_patrol_index % patrol_points.size()]
	if not brain.nav_to(target, delta, INVESTIGATE_SPEED):
		_patrol_index += 1
		_patrol_dwell = PATROL_DWELL_SECS * randf_range(0.6, 1.6)
		_patrol_sweep = randf() * TAU

## Coming off a fight, pick up the route at the NEAREST post rather than
## whichever index we abandoned — otherwise a guard who chased someone across
## the site turns around and walks the whole loop back to where he was.
func _resume_patrol() -> void:
	if patrol_points.is_empty():
		return
	var best := 0
	var best_d := INF
	for i in patrol_points.size():
		var d: float = body.global_position.distance_to(patrol_points[i])
		if d < best_d:
			best_d = d
			best = i
	_patrol_index = best
	_patrol_dwell = 0.0

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
		_resume_patrol()
		_wander_target = Vector3.INF
		_wander_pause = 0.5

func _tick_fight(delta: float) -> void:
	if vanisher and _tick_vanish(delta):
		return
	if disciplined and _suppress_role():
		_tick_suppress(delta)
	else:
		brain.tick(delta)
	# The brain lost the track — the chase is over. Go poke at the last-known
	# position, then stand down and walk home (IDLE wanders near spawn, and
	# nav_to crosses the whole district to get there).
	if brain.lost_lkp != Vector3.INF:
		var lkp := brain.lost_lkp
		brain.lost_lkp = Vector3.INF
		brain.leash_radius = _base_leash
		state = State.SUSPICIOUS
		_investigate = lkp
		_linger = SUSPICIOUS_LINGER_SECS
	elif brain.threat == null:
		# The track evaporated with no lost fix — target out of range while
		# unpinned, or the hostility itself ended (a grudge forgiven). Don't
		# stand in FIGHT forever aiming at nothing.
		brain.leash_radius = _base_leash
		state = State.SUSPICIOUS
		_investigate = Vector3.INF
		_linger = SUSPICIOUS_LINGER_SECS

# ── Clan doctrine: vanish ────────────────────────────────────────────────────

var _vanish_ready_ms := 0
var _vanish_to := Vector3.INF

## Drop the cloud and pick a spot around the threat's flank to reappear from.
func _try_vanish() -> void:
	if not body.is_alive() or Time.get_ticks_msec() < _vanish_ready_ms:
		return
	_vanish_ready_ms = Time.get_ticks_msec() + int(VANISH_COOLDOWN * 1000.0)
	SmokeBomb.pop(get_tree().current_scene, body.global_position)
	var away := body.global_position - brain.threat_pos()
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	# Sidestep, not retreat: circle the threat rather than break contact.
	var arc := deg_to_rad(75.0) * (1.0 if (body.get_instance_id() & 1) == 0 else -1.0)
	_vanish_to = body.global_position \
		+ away.normalized().rotated(Vector3.UP, arc) * VANISH_DASH

## Returns true while the dash owns the body.
func _tick_vanish(delta: float) -> bool:
	if _vanish_to == Vector3.INF:
		return false
	if not brain.nav_to(_vanish_to, delta, VANISH_SPEED, brain.threat_pos()):
		_vanish_to = Vector3.INF
		return false
	return true

# ── Corp discipline: bounding overwatch + the mender ─────────────────────────

## Deterministic role split: sort the pack's living members, alternate
## suppressor/advancer by index, swap the phase every few seconds. Adjacent
## members always hold OPPOSITE roles — someone is always shooting while
## someone is always moving.
func _suppress_role() -> bool:
	var alive: Array = []
	for member in get_tree().get_nodes_in_group("pack_" + pack_id):
		if is_instance_valid(member) and member is EnemyController:
			var ec := member as EnemyController
			if is_instance_valid(ec.body) and ec.body.is_alive():
				alive.append(ec)
	if alive.size() < 2:
		return false  # alone: fight with the whole brain
	alive.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	var idx := alive.find(self)
	var phase := int(Time.get_ticks_msec() / int(OVERWATCH_SWAP_SECS * 1000.0))
	return (idx + phase) % 2 == 0

var _suppress_fired := 0
var _suppress_pause := 0.0

## Overwatch: hold, face the believed position, cadenced bursts at it —
## trigger discipline, not panic fire. The advancing element flanks under it.
func _tick_suppress(delta: float) -> void:
	brain.idle_stop(delta)
	var aim := brain.threat_pos()
	_face_point(aim)
	_suppress_pause -= delta
	if _suppress_pause > 0.0:
		return
	var fired := false
	if brain.threat != null and body.get_node("Shooter").can_fire(brain.threat):
		fired = (body.get_node("Shooter") as Shooter).try_fire(brain.threat)
	else:
		fired = (body.get_node("Shooter") as Shooter).fire_wild(aim)
	if fired:
		_suppress_fired += 1
		if _suppress_fired >= SUPPRESS_BURST:
			_suppress_fired = 0
			_suppress_pause = SUPPRESS_PAUSE_SECS

## The mender: any pack mate with a drained shield inside range gets the
## beam before anything else happens. Returns true when supporting.
func _tick_support(delta: float) -> bool:
	var shooter := body.get_node("Shooter") as Shooter
	var heal_slot := -1
	for i in body.gear_slots.size():
		var g: GearItem = body.gear_slots[i]
		if g != null and g.heals:
			heal_slot = i
			break
	if heal_slot < 0:
		return false
	var patient: Character = null
	var worst := 0.85  # only bother below this shield fraction
	for member in get_tree().get_nodes_in_group("pack_" + pack_id):
		if not is_instance_valid(member) or not (member is EnemyController):
			continue
		var mate := (member as EnemyController).body
		if mate == null or not is_instance_valid(mate) or mate == body \
				or not mate.is_alive() or mate.max_shield <= 0.0:
			continue
		var frac := mate.shield / mate.max_shield
		if frac < worst:
			worst = frac
			patient = mate
	if patient == null:
		return false
	body.select_slot(heal_slot)
	var dist := body.global_position.distance_to(patient.global_position)
	var g: GearItem = body.gear_slots[heal_slot]
	if dist <= g.fire_range and Cover.can_hit(body.muzzle_position(), patient):
		brain.idle_stop(delta)
		_face_point(patient.global_position)
		shooter.try_heal(patient)
	else:
		brain.nav_to(patient.global_position, delta, INVESTIGATE_SPEED,
			patient.global_position)
	return true

func _face_point(point: Vector3) -> void:
	var dir := point - body.global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		body.rotation.y = atan2(-dir.x, -dir.z)

## Morale test — called on every pack-mate death. Units with morale break
## when the pack is cut to MORALE_BREAK_FRAC of its spawn strength: they run,
## catch their breath, then slink back suspicious. Machines and fanatics
## (has_morale false) never take the test.
func check_morale() -> void:
	if not has_morale or state == State.FLEE or _pack_initial <= 0 or not body.is_alive():
		return
	var alive := 0
	for member in get_tree().get_nodes_in_group("pack_" + pack_id):
		if member is EnemyController and (member as EnemyController).body.is_alive():
			alive += 1
	if float(alive) / float(_pack_initial) <= morale_break_frac:
		state = State.FLEE
		brain.leash_radius = _base_leash  # broken nerve ends the chase too
		_flee_timer = FLEE_RECOVER_SECS
		var away := body.global_position - _nearest_hostile_pos()
		away.y = 0.0
		if away.length_squared() < 0.01:
			away = Vector3.FORWARD
		_flee_target = body.global_position + away.normalized() * FLEE_DIST

func _tick_flee(delta: float) -> void:
	if _flee_target != Vector3.INF:
		if not brain.nav_to(_flee_target, delta, CombatBrain.SPEED, Vector3.INF):
			_flee_target = Vector3.INF  # made it (or nowhere left to run)
		return
	_stand(delta)
	_flee_timer -= delta
	if _flee_timer <= 0.0:
		# Nerve recovered — creep back toward where the fight was.
		state = State.SUSPICIOUS
		_investigate = brain.threat_pos() if brain.threat != null else _spawn
		_linger = SUSPICIOUS_LINGER_SECS

func _nearest_hostile_pos() -> Vector3:
	var best := body.global_position + Vector3.FORWARD
	var best_d := INF
	for node in Factions.hostiles_of(get_tree(), body.team):
		var c := node as Character
		var d := body.global_position.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c.global_position
	return best

## A player-team character visible inside sight range → fight, tell the pack.
func _check_sight() -> bool:
	for node in Factions.hostiles_of(get_tree(), body.team):
		var c := node as Character
		if body.global_position.distance_to(c.global_position) > aggro_radius:
			continue
		if Cover.exposure(body.muzzle_position(), c) > Cover.FULL_COVER_MAX:
			brain.pin_threat(c)
			_enter_fight()
			return true
	return false

func _stand(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= Character.GRAVITY * delta
	body.velocity.x = 0.0
	body.velocity.z = 0.0
	body.move_and_slide()
