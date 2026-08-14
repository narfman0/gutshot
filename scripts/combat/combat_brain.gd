## Shared combat AI — used by squad followers AND enemies, so both sides fight
## the same way: pick a cover point that breaks line of sight to the threat,
## hold, pop out to fire a burst, duck back; flank when damage-starved.
##
## The brain does NOT run its own _physics_process — its owner controller
## (EnemyController / SquadFollow) calls tick(delta) while engaged, so exactly
## one component drives the body each frame.
##
## Movement is manual waypoint-following over NavigationServer3D.map_get_path
## (NavigationAgent3D's per-frame next-position oscillated when driven this
## way — deterministic waypoints are simpler to reason about and to test).
class_name CombatBrain
extends Node

# ── Tuning ───────────────────────────────────────────────────────────────────
const SPEED := 5.0
const ENGAGE_RANGE := 18.0        # metres — acquire threats inside this
const COVER_SEARCH_RADIUS := 12.0 # metres — how far to shop for cover
const COVER_RING_POINTS := 8      # sample points around each cover prop
const COVER_STANDOFF := 0.9       # metres outside the prop's collision extent
const HOLD_SECS := 0.6            # crouched-in-cover beat between pop-outs
const POP_MAX_SECS := 2.2         # give up a pop-out that never finds LOS
const BURST_SHOTS := 3            # shots per pop-out window
const FLANK_TRIGGER_SECS := 4.0   # no damage dealt this long → go around
const FLANK_ARC_DEG := 90.0
const GRENADE_STARVE_SECS := 2.5  # dug-in target this long → try a grenade first
const MELEE_RUSH_MULT := 1.35     # blades close FAST — the rush must be scary
const ARRIVE_DIST := 0.6
const WAYPOINT_DIST := 0.5        # advance to the next path corner inside this
const REPATH_DIST := 1.0          # re-query when the destination drifts this far

enum State { ADVANCE, SEEK_COVER, HOLD, POP, FLANK }

var body: Character
var shooter: Shooter

## Followers pass a leash target (the leader); enemies leash to their spawn.
var leash_center_node: Node3D = null
var leash_radius := 12.0

const THREAT_PIN_SECS := 6.0    # how long "I know where that shot came from" holds
const SIGHT_MEMORY_SECS := 8.0  # unseen this long (and unpinned) → track lost

var state: State = State.ADVANCE
var threat: Character = null
## Last-known position: where this brain THINKS the threat is. Updated only
## while the threat is actually visible — a target that relocates unseen gets
## shot at where it used to be.
var threat_lkp := Vector3.INF
## Set when the track was dropped; the owner controller consumes it as an
## investigation point (enemies go SUSPICIOUS toward it).
var lost_lkp := Vector3.INF
var _threat_pin_until_ms := 0
var _last_seen_ms := 0

var _spawn := Vector3.ZERO
var _cover_point := Vector3.INF
var _flank_point := Vector3.INF
var _state_timer := 0.0
var _burst_left := 0
var _starve_timer := 0.0

var _waypoints := PackedVector3Array()
var _wp_index := 0
var _path_dest := Vector3.INF

func _ready() -> void:
	body = get_parent() as Character
	shooter = body.get_node("Shooter")
	_spawn = body.global_position

func _leash_center() -> Vector3:
	if leash_center_node != null and is_instance_valid(leash_center_node):
		return leash_center_node.global_position
	return _spawn

func _clamp_to_leash(point: Vector3) -> Vector3:
	var center := _leash_center()
	var flat := point - center
	flat.y = 0.0
	if flat.length() <= leash_radius:
		return point
	return center + flat.normalized() * leash_radius

## Being shot at reveals the shooter — engage them regardless of range, and
## remember the position read for a few seconds.
func pin_threat(attacker: Character) -> void:
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_alive():
		return
	threat = attacker
	# The muzzle flash IS a position fix — the pin comes with a fresh LKP.
	threat_lkp = attacker.global_position
	_last_seen_ms = Time.get_ticks_msec()
	_threat_pin_until_ms = Time.get_ticks_msec() + int(THREAT_PIN_SECS * 1000.0)

## Where the brain believes the threat stands — true position while visible,
## the stale LKP after they slip away. All aiming/positioning decisions use
## this, so relocating unseen actually shakes pursuit.
func threat_pos() -> Vector3:
	if threat_lkp != Vector3.INF:
		return threat_lkp
	return threat.global_position if threat != null and is_instance_valid(threat) \
		else body.global_position

## Chest-height eye point at the believed position (for cover-safety rays).
func _threat_eye() -> Vector3:
	return threat_pos() + Vector3(0, 1.3 * Character.VERTICAL_SQUASH, 0)

## Nearest living opposing character within engage range; a pinned threat
## (return fire) overrides the range gate while the pin lasts.
func acquire_threat() -> Character:
	if threat != null and is_instance_valid(threat) and threat.is_alive() \
			and Time.get_ticks_msec() < _threat_pin_until_ms:
		return threat
	if threat != null and is_instance_valid(threat) and threat.is_alive() \
			and body.global_position.distance_to(threat.global_position) <= ENGAGE_RANGE:
		return threat
	threat = null
	var best_d := ENGAGE_RANGE
	for node in Factions.hostiles_of(body.get_tree(), body.team):
		var c := node as Character
		var d := body.global_position.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			threat = c
	return threat

## Drive one combat frame. Callers ensure a threat context exists (aggro /
## engage checks live in the owner controllers).
func tick(delta: float) -> void:
	if body == null or not body.is_alive():
		return
	if acquire_threat() == null:
		idle_stop(delta)
		return
	# Track the threat only while it is actually visible; an unseen threat is
	# fought at its last-known position until the memory runs out.
	var now := Time.get_ticks_msec()
	if Cover.exposure(body.muzzle_position(), threat) > Cover.FULL_COVER_MAX:
		threat_lkp = threat.global_position
		_last_seen_ms = now
	elif now - _last_seen_ms > int(SIGHT_MEMORY_SECS * 1000.0) \
			and now >= _threat_pin_until_ms:
		# Lost them. Hand the stale fix to the controller and stand down.
		lost_lkp = threat_lkp
		threat = null
		threat_lkp = Vector3.INF
		idle_stop(delta)
		return
	# Blades don't shop cover — a melee brain is a guided missile with legs:
	# run the threat down, swing when close. (The demon-horde/ninja recipe.)
	var g := shooter.gear()
	if g != null and g.fire_mode == GearItem.FireMode.MELEE:
		_tick_melee(delta)
		return
	_starve_timer += delta
	_state_timer -= delta
	match state:
		State.ADVANCE:
			_tick_advance(delta)
		State.SEEK_COVER:
			_tick_seek_cover(delta)
		State.HOLD:
			_tick_hold(delta)
		State.POP:
			_tick_pop(delta)
		State.FLANK:
			_tick_flank(delta)
	# Dug-in target: try to frag them out before committing to the flank walk.
	if _starve_timer >= GRENADE_STARVE_SECS and state != State.FLANK:
		if _try_grenade():
			_starve_timer = 0.0
	if _starve_timer >= FLANK_TRIGGER_SECS and state != State.FLANK:
		_enter_flank()

func _tick_melee(delta: float) -> void:
	var reach: float = shooter.gear().fire_range
	var flat := threat_pos() - body.global_position
	flat.y = 0.0
	if flat.length() > reach * 0.8:
		nav_to(_clamp_to_leash(threat_pos()), delta, SPEED * MELEE_RUSH_MULT, threat_pos())
	else:
		idle_stop(delta)
		_face(threat_pos())
		shooter.try_fire(threat)

## Throw a frag at the threat if we carry one, it's off cooldown, and the
## threat is inside throw range. Both followers and enemies use this — cover
## campers get cover-called on either side.
func _try_grenade() -> bool:
	for ability in body.action_slots:
		var frag := ability as FragGrenadeAbility
		if frag == null:
			continue
		var flat := threat_pos() - body.global_position
		flat.y = 0.0
		if flat.length() > frag.throw_range:
			return false
		return body.activate_ability(frag, threat_pos())
	return false

func idle_stop(delta: float) -> void:
	body.velocity.x = move_toward(body.velocity.x, 0.0, SPEED * 8.0 * delta)
	body.velocity.z = move_toward(body.velocity.z, 0.0, SPEED * 8.0 * delta)
	_apply_gravity(delta)
	body.move_and_slide()

# ── States ───────────────────────────────────────────────────────────────────

func _tick_advance(delta: float) -> void:
	# Cover only matters inside fighting range — a pursuer 30 m behind a
	# fleeing threat closes the gap first, THEN fights from cover.
	var flat := threat_pos() - body.global_position
	flat.y = 0.0
	if flat.length() <= ENGAGE_RANGE:
		var found := _pick_cover_point()
		if found != Vector3.INF:
			_cover_point = found
			state = State.SEEK_COVER
			return
	nav_to(_clamp_to_leash(threat_pos()), delta, SPEED, threat_pos())
	_fire_if_able()

func _tick_seek_cover(delta: float) -> void:
	var flat := _cover_point - body.global_position
	flat.y = 0.0
	if flat.length() <= ARRIVE_DIST:
		state = State.HOLD
		_state_timer = HOLD_SECS
		return
	# Run-and-gun on the way in: face the threat and fire whenever the shot is
	# there (moving accuracy penalty applies) — no free repositioning window.
	if not nav_to(_cover_point, delta, SPEED, threat_pos()):
		# No path to the point (off-navmesh) — shop again from scratch.
		_cover_point = Vector3.INF
		state = State.ADVANCE
		return
	_fire_if_able()

func _tick_hold(delta: float) -> void:
	idle_stop(delta)
	_face(threat_pos())
	# The threat pulled away — cover this far back is camping, not fighting.
	var flat := threat_pos() - body.global_position
	flat.y = 0.0
	if flat.length() > ENGAGE_RANGE * 1.2:
		_cover_point = Vector3.INF
		state = State.ADVANCE
		return
	# Cover crumbled (threat moved / flanked us)? Re-seek.
	if Cover.exposure(_threat_eye(), body) > Cover.EXPOSED_MIN:
		_cover_point = Vector3.INF
		state = State.ADVANCE
		return
	if _state_timer <= 0.0:
		state = State.POP
		_state_timer = POP_MAX_SECS
		_burst_left = BURST_SHOTS

func _tick_pop(delta: float) -> void:
	# Strafe sideways out of cover until the shot opens up, fire the burst,
	# then duck back to the cover point.
	if _state_timer <= 0.0 or _burst_left <= 0:
		state = State.SEEK_COVER
		return
	if shooter.can_fire(threat):
		idle_stop(delta)
		_face(threat_pos())
		if shooter.try_fire(threat):
			_burst_left -= 1
			if shooter.last_shot_hit:
				_starve_timer = 0.0
	else:
		# No shot on the real body. If the threat slipped from view, suppress
		# the spot we believe they hold; either way work the angle.
		if Time.get_ticks_msec() - _last_seen_ms > 400:
			if shooter.fire_wild(threat_pos()):
				_burst_left -= 1
		var to_threat := (threat_pos() - body.global_position).normalized()
		var side := to_threat.cross(Vector3.UP).normalized()
		# Deterministic side pick per body so pairs don't mirror-dance.
		if (body.get_instance_id() & 1) == 0:
			side = -side
		_move_direct(side, delta)
		_face(threat_pos())

func _enter_flank() -> void:
	state = State.FLANK
	_starve_timer = 0.0
	var to_me := body.global_position - threat_pos()
	to_me.y = 0.0
	var dist := maxf(to_me.length(), 4.0)
	var arc := deg_to_rad(FLANK_ARC_DEG) * (1.0 if (body.get_instance_id() & 1) == 0 else -1.0)
	_flank_point = _clamp_to_leash(
		threat_pos() + to_me.normalized().rotated(Vector3.UP, arc) * dist)

func _tick_flank(delta: float) -> void:
	var flat := _flank_point - body.global_position
	flat.y = 0.0
	if flat.length() <= ARRIVE_DIST or not nav_to(_flank_point, delta, SPEED, threat_pos()):
		_cover_point = Vector3.INF
		state = State.ADVANCE
		return
	_fire_if_able()

# ── Cover shopping ───────────────────────────────────────────────────────────

## Ring-sample every cover prop in range; pick the nearest point that breaks
## the threat's line to a standing torso there. Vector3.INF when nothing works.
func _pick_cover_point() -> Vector3:
	var best := Vector3.INF
	var best_d := COVER_SEARCH_RADIUS
	var space := body.get_world_3d().direct_space_state
	var threat_eye: Vector3 = _threat_eye()
	for prop in body.get_tree().get_nodes_in_group("cover"):
		var prop_pos := (prop as Node3D).global_position
		if body.global_position.distance_to(prop_pos) > COVER_SEARCH_RADIUS:
			continue
		var ring := _prop_extent(prop) + COVER_STANDOFF
		for i in COVER_RING_POINTS:
			var ang := TAU * i / COVER_RING_POINTS
			var point := prop_pos + Vector3(cos(ang), 0, sin(ang)) * ring
			point.y = body.global_position.y
			point = _clamp_to_leash(point)
			var d := body.global_position.distance_to(point)
			if d >= best_d:
				continue
			# Torso ray from the threat's muzzle: blocked = the point is safe.
			var query := PhysicsRayQueryParameters3D.create(
				threat_eye, point + Vector3(0, 1.3, 0), Layers.LOS_MASK)
			if not space.intersect_ray(query).is_empty():
				best = point
				best_d = d
	return best

## Horizontal half-extent of a cover prop, from its first collision shape —
## the sample ring must sit outside the prop, not inside it.
static func _prop_extent(prop: Node) -> float:
	for child in prop.get_children():
		var cs := child as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var shape := cs.shape
		if shape is BoxShape3D:
			var size: Vector3 = (shape as BoxShape3D).size
			return maxf(size.x, size.z) * 0.5
		if shape is CylinderShape3D:
			return (shape as CylinderShape3D).radius
		if shape is SphereShape3D:
			return (shape as SphereShape3D).radius
	return 1.0

# ── Movement (manual waypoints over the navigation map) ──────────────────────

## Path toward `dest` one physics frame. face_point: look there while moving
## (Vector3.INF → face along the path). Returns false when there is no path
## or every waypoint is consumed (arrived or unreachable) — callers decide.
## Public: SquadFollow reuses it for formation movement.
func nav_to(dest: Vector3, delta: float, speed: float = SPEED,
		face_point: Vector3 = Vector3.INF) -> bool:
	if _path_dest == Vector3.INF or dest.distance_to(_path_dest) > REPATH_DIST:
		_path_dest = dest
		_waypoints = NavigationServer3D.map_get_path(
			body.get_world_3d().navigation_map, body.global_position, dest, true)
		_wp_index = 0
	while _wp_index < _waypoints.size():
		var wp := _waypoints[_wp_index]
		var flat := wp - body.global_position
		flat.y = 0.0
		if flat.length() <= WAYPOINT_DIST:
			_wp_index += 1
		else:
			break
	if _wp_index >= _waypoints.size():
		_path_dest = Vector3.INF
		idle_stop(delta)
		return false
	var dir := _waypoints[_wp_index] - body.global_position
	dir.y = 0.0
	dir = dir.normalized()
	body.velocity.x = dir.x * speed
	body.velocity.z = dir.z * speed
	_apply_gravity(delta)
	body.move_and_slide()
	if face_point != Vector3.INF:
		_face(face_point)
	else:
		_face(body.global_position + dir)
	return true

func _move_direct(dir: Vector3, delta: float) -> void:
	body.velocity.x = dir.x * SPEED
	body.velocity.z = dir.z * SPEED
	_apply_gravity(delta)
	body.move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= Character.GRAVITY * delta

func _fire_if_able() -> void:
	if shooter.try_fire(threat) and shooter.last_shot_hit:
		_starve_timer = 0.0

func _face(point: Vector3) -> void:
	var dir := point - body.global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		body.rotation.y = atan2(-dir.x, -dir.z)
