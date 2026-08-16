## Follower AI for non-active squad members: out of combat, hold a formation
## offset behind the leader; in combat, fight autonomously through the shared
## CombatBrain (cover, pop-out bursts, flanks) leashed to the leader.
class_name SquadFollow
extends Node

const SPEED := 8.5           # slightly under the leader's so they trail
## Beyond this from the leader, catching up outranks EVERYTHING — the crew
## follows the player first and fights second. Playtest 2026-08-15: the party
## kept stopping to fight and getting left behind.
const CATCHUP_DIST := 14.0
## ...and they sprint to close it. The player sprints at 14.25 against a
## follow speed of 8.5, so without this they can never actually catch up —
## which is half of why they appeared to stop following at all.
const CATCHUP_SPEED := 12.5
## Last-resort unstick. A follower wedged against geometry re-paths every
## frame and gets the same short path back, so it stands there for good —
## which is the other half of "the party stopped following". If one is far
## behind AND has not moved for this long, warp it to the leader.
const STUCK_SECS := 3.0
const STUCK_SPEED := 0.6
const ENGAGE_DIST := 12.0    # enemy this close to ME → fight
const LEASH_RADIUS := 11.0
const STOP_DIST := 1.4
const HEAL_BELOW_FRAC := 0.75  # medic beams mates under this HP fraction

var enabled := false
var leader: Character = null
## Slot in the wedge behind the leader, set by Squad.
var formation_offset := Vector3(1.5, 0, 1.5)

var body: Character
var brain: CombatBrain
var _stuck_for := 0.0

func _ready() -> void:
	body = get_parent() as Character
	brain = body.get_node("CombatBrain")
	brain.leash_radius = LEASH_RADIUS
	# Followers return fire too when someone opens up on them from afar.
	body.shot_at.connect(func(attacker: Character): brain.pin_threat(attacker))

func _physics_process(delta: float) -> void:
	if not enabled or body == null or not body.is_alive():
		return
	brain.leash_center_node = leader
	if _tick_revive_assist(delta):
		return
	if _tick_medic(delta):
		return
	if _in_combat():
		_stuck_for = 0.0
		brain.tick(delta)
	else:
		_follow(delta)
		_tick_unstick(delta)

## Warp a hopelessly stuck follower to the leader. Deliberately blunt: a
## squadmate quietly reappearing behind you reads far better than one left
## standing against a wall on the other side of the district.
func _tick_unstick(delta: float) -> void:
	if leader == null or not is_instance_valid(leader):
		_stuck_for = 0.0
		return
	var gap := body.global_position.distance_to(leader.global_position)
	if gap <= CATCHUP_DIST \
			or Vector2(body.velocity.x, body.velocity.z).length() > STUCK_SPEED:
		_stuck_for = 0.0
		return
	_stuck_for += delta
	if _stuck_for < STUCK_SECS:
		return
	_stuck_for = 0.0
	var slot := leader.global_position \
		+ formation_offset.rotated(Vector3.UP, leader.rotation.y)
	body.global_position = NavigationServer3D.map_get_closest_point(
		body.get_world_3d().navigation_map, slot)
	body.velocity = Vector3.ZERO
	brain.forget_path()

## A downed mate outranks everything: the CLOSEST follower breaks off, runs
## over, and stands the revive channel. Other followers keep fighting.
func _tick_revive_assist(delta: float) -> bool:
	var downed_mate: Character = null
	var my_d := INF
	for node in body.get_tree().get_nodes_in_group("team_%d" % body.team):
		var mate := node as Character
		if mate == null or not mate.downed:
			continue
		var d := body.global_position.distance_to(mate.global_position)
		if d < my_d:
			my_d = d
			downed_mate = mate
	if downed_mate == null:
		return false
	# Only the closest FOLLOWER responds (the player drives the active char).
	for node in body.get_tree().get_nodes_in_group("team_%d" % body.team):
		var other := node as Character
		if other == null or other == body or not other.is_alive():
			continue
		var follow := other.get_node_or_null("SquadFollow") as SquadFollow
		if follow == null or not follow.enabled:
			continue
		if other.global_position.distance_to(downed_mate.global_position) < my_d - 0.5:
			return false
	if my_d <= Character.REVIVE_RADIUS * 0.8:
		# In the channel — stand it (dying to do so is the player's problem).
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		if not body.is_on_floor():
			body.velocity.y -= Character.GRAVITY * delta
		body.move_and_slide()
		return true
	return brain.nav_to(downed_mate.global_position, delta, SPEED, downed_mate.global_position)

## Heal-gun carrier: patching a wounded squadmate beats shooting. Stands and
## beams whenever a hurt mate is in range/LOS; otherwise falls through to the
## normal fight/follow behavior (the leash keeps the medic near the action).
func _tick_medic(delta: float) -> bool:
	var heal_slot := -1
	for i in body.gear_slots.size():
		var g: GearItem = body.gear_slots[i]
		if g != null and g.heals:
			heal_slot = i
			break
	if heal_slot == -1:
		return false
	var patient: Character = null
	var worst_frac := HEAL_BELOW_FRAC
	for node in body.get_tree().get_nodes_in_group("team_%d" % body.team):
		var mate := node as Character
		if mate == null or mate == body or not mate.is_alive():
			continue
		var frac := mate.hp / mate.max_hp
		if frac < worst_frac:
			worst_frac = frac
			patient = mate
	if patient == null:
		# Nobody hurt: put the gun away so fights use the primary.
		if body.active_slot == heal_slot:
			body.select_slot(0)
		return false
	body.select_slot(heal_slot)
	var heal_gear: GearItem = body.gear_slots[heal_slot]
	var in_reach: bool = body.global_position.distance_to(patient.global_position) <= heal_gear.fire_range \
		and Cover.can_hit(body.muzzle_position(), patient)
	if in_reach:
		# Stand and beam — try_heal fires whenever its rate/reload clocks allow.
		brain.idle_stop(delta)
		body.rotation.y = atan2(
			-(patient.global_position.x - body.global_position.x),
			-(patient.global_position.z - body.global_position.z))
		body.get_node("Shooter").try_heal(patient)
		return true
	# Can't reach the patient from here — close in on them.
	return brain.nav_to(patient.global_position, delta, SPEED, patient.global_position)

## Fighting is the exception; following is the rule.
##
## This used to return true for any hostile within 16 m of the follower OR
## the leader, and for a pinned threat at ANY distance — which in a district
## where gangs are hostile on sight was very nearly always, so followers
## fought instead of following and fell behind for good.
func _in_combat() -> bool:
	# Left behind? Then nothing else matters. Catch up.
	if leader != null and is_instance_valid(leader) \
			and body.global_position.distance_to(leader.global_position) > CATCHUP_DIST:
		return false
	# Being shot at still counts — but only by someone actually near us, not
	# by whoever last pinged us from across the district.
	if brain.threat != null and is_instance_valid(brain.threat) \
			and brain.threat.is_alive() \
			and body.global_position.distance_to(brain.threat.global_position) \
				<= ENGAGE_DIST * 1.5:
		return true
	# Hostiles close to ME. The leader's own attackers are not counted: the
	# follower is trailing the leader anyway, so it arrives and engages a
	# beat later instead of stopping dead in a corridor.
	for enemy in Factions.hostiles_of(body.get_tree(), body.team):
		if (enemy as Character).global_position.distance_to(body.global_position) \
				<= ENGAGE_DIST:
			return true
	return false

func _follow(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= Character.GRAVITY * delta
	if leader == null or not is_instance_valid(leader):
		body.velocity.x = move_toward(body.velocity.x, 0.0, SPEED * 8.0 * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, SPEED * 8.0 * delta)
		body.move_and_slide()
		return
	# Offset rotates with the leader so the wedge stays behind them.
	var slot := leader.global_position + formation_offset.rotated(Vector3.UP, leader.rotation.y)
	var to_slot := slot - body.global_position
	to_slot.y = 0.0
	# Sprint when trailing badly, walk when close — the crew reads as keeping
	# up rather than teleporting or dawdling.
	var follow_speed := CATCHUP_SPEED if to_slot.length() > CATCHUP_DIST else SPEED
	if to_slot.length() <= STOP_DIST:
		body.velocity.x = move_toward(body.velocity.x, 0.0, SPEED * 8.0 * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, SPEED * 8.0 * delta)
		body.move_and_slide()
		return
	brain.nav_to(slot, delta, follow_speed)
