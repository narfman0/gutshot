## EMP Charge — strips shields in a radius and staggers machines.
##
## The counter to the two things that ignore ordinary pressure: corp security
## hides behind a regenerating shield layer, and the Assembly has no morale to
## break. This deletes the first and briefly takes the second off the board,
## which makes it the crew's answer to a disciplined pack rather than another
## damage number.
class_name EmpChargeAbility
extends Ability

@export var throw_range := 12.0
@export var radius := 5.0
@export var fuse_secs := 0.7
@export var machine_stagger := 3.0

func activate(caster: Node, target_point: Vector3) -> bool:
	var body := caster as Character
	if body == null:
		return false
	var flat := target_point - body.global_position
	flat.y = 0.0
	if flat.length() > throw_range:
		target_point = body.global_position + flat.normalized() * throw_range
	target_point.y = body.global_position.y
	var scene := body.get_tree().current_scene
	var t: Telegraph = Telegraph.show_circle(scene, target_point, radius,
		fuse_secs, Color(0.4, 0.8, 1.0, 0.30))
	t.fired.connect(func(): _detonate(body, target_point))
	return true

func _detonate(body: Character, at: Vector3) -> void:
	if not is_instance_valid(body):
		return
	AudioManager.play_sfx("shield_hit", 3.0)
	Vfx.explosion(body.get_tree().current_scene, at + Vector3(0, 0.6, 0), radius * 0.5)
	for node in body.get_tree().get_nodes_in_group("characters"):
		var c := node as Character
		if c == null or not is_instance_valid(c) or not c.is_alive():
			continue
		if not Factions.hostile(body.team, c.team):
			continue
		if c.global_position.distance_to(at) > radius:
			continue
		if c.shield > 0.0:
			c.shield = 0.0
			c.shield_changed.emit(c.shield, c.max_shield)
		# Machines don't rout, so the EMP is what "breaking" looks like for
		# them: a few seconds of nothing.
		if c.team == Factions.ASSEMBLY:
			c.stagger_until_ms = Time.get_ticks_msec() + int(machine_stagger * 1000.0)
