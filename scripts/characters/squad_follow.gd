## Follower AI for non-active squad members: out of combat, hold a formation
## offset behind the leader; in combat, fight autonomously through the shared
## CombatBrain (cover, pop-out bursts, flanks) leashed to the leader.
class_name SquadFollow
extends Node

const SPEED := 5.6           # slightly under the leader's so they trail
const GRAVITY := 9.8
const ENGAGE_DIST := 16.0    # enemy this close to me or the leader → fight
const LEASH_RADIUS := 11.0
const STOP_DIST := 1.4

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
	if _in_combat():
		brain.tick(delta)
	else:
		_follow(delta)

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
