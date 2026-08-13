## Follower AI for non-active squad members: out of combat, hold a formation
## offset behind the leader; in combat, fight autonomously through the shared
## CombatBrain (cover, pop-out bursts, flanks) leashed to the leader.
class_name SquadFollow
extends Node

const SPEED := 8.5           # slightly under the leader's so they trail
const GRAVITY := 9.8
const ENGAGE_DIST := 16.0    # enemy this close to me or the leader → fight
const LEASH_RADIUS := 11.0
const STOP_DIST := 1.4
const HEAL_BELOW_FRAC := 0.75  # medic beams mates under this HP fraction

var enabled := false
var leader: Character = null
## Slot in the wedge behind the leader, set by Squad.
var formation_offset := Vector3(1.5, 0, 1.5)

var body: Character
var brain: CombatBrain

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
		brain.tick(delta)
	else:
		_follow(delta)

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
			body.velocity.y -= GRAVITY * delta
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

func _in_combat() -> bool:
	# A pinned threat (someone shot at us) is combat no matter the distance.
	if brain.threat != null and is_instance_valid(brain.threat) \
			and brain.threat.is_alive():
		return true
	var anchors: Array = [body]
	if leader != null and is_instance_valid(leader):
		anchors.append(leader)
	for node in body.get_tree().get_nodes_in_group("team_%d" % (1 - body.team)):
		var enemy := node as Character
		if enemy == null or not enemy.is_alive():
			continue
		for anchor in anchors:
			if enemy.global_position.distance_to(anchor.global_position) <= ENGAGE_DIST:
				return true
	return false

func _follow(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= GRAVITY * delta
	if leader == null or not is_instance_valid(leader):
		body.velocity.x = move_toward(body.velocity.x, 0.0, SPEED * 8.0 * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, SPEED * 8.0 * delta)
		body.move_and_slide()
		return
	# Offset rotates with the leader so the wedge stays behind them.
	var slot := leader.global_position + formation_offset.rotated(Vector3.UP, leader.rotation.y)
	var to_slot := slot - body.global_position
	to_slot.y = 0.0
	if to_slot.length() <= STOP_DIST:
		body.velocity.x = move_toward(body.velocity.x, 0.0, SPEED * 8.0 * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, SPEED * 8.0 * delta)
		body.move_and_slide()
		return
	brain.nav_to(slot, delta, SPEED)
