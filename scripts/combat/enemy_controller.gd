## Enemy controller — a thin aggro wrapper over the shared CombatBrain.
## IDLE until a player-team character enters aggro_radius (or a pack-mate
## aggroes), then the brain owns the fight: cover, pop-out bursts, flanks.
class_name EnemyController
extends Node

const GRAVITY := 9.8

@export var aggro_radius := 12.0
## Enemies sharing a pack_id aggro together the moment one of them does.
@export var pack_id := ""
@export var leash_radius := 25.0

var body: Character
var brain: CombatBrain
var _aggroed := false

func _ready() -> void:
	body = get_parent() as Character
	brain = body.get_node("CombatBrain")
	brain.leash_radius = leash_radius
	if pack_id != "":
		add_to_group("pack_" + pack_id)
	body.character_died.connect(func(_c): set_physics_process(false))
	# Being fired at — hit OR miss, any distance — always draws return fire:
	# the muzzle flash reveals exactly who shot, so pin them as the threat.
	body.shot_at.connect(func(attacker: Character):
		alerted()
		brain.pin_threat(attacker))

func alerted() -> void:
	if _aggroed:
		return
	_aggroed = true
	if pack_id != "":
		for member in get_tree().get_nodes_in_group("pack_" + pack_id):
			if member != self and member is EnemyController:
				(member as EnemyController).alerted()

func _physics_process(delta: float) -> void:
	if body == null or not body.is_alive():
		return
	if not _aggroed:
		_check_aggro()
		if not body.is_on_floor():
			body.velocity.y -= GRAVITY * delta
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		body.move_and_slide()
		return
	brain.tick(delta)

func _check_aggro() -> void:
	for node in get_tree().get_nodes_in_group("team_%d" % (1 - body.team)):
		var c := node as Character
		if c != null and c.is_alive() \
				and body.global_position.distance_to(c.global_position) <= aggro_radius:
			alerted()
			return

## Getting shot is an alert even from beyond aggro range.
func on_damaged() -> void:
	alerted()
