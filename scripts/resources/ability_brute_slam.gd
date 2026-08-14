## The brute's slam — a telegraphed circle at the target's feet (orange:
## footwork is the answer). Everyone hostile still inside when it fires
## takes the hit; the dodge IS the defense.
class_name BruteSlamAbility
extends Ability

@export var radius := 2.8
@export var windup := 1.1
@export var damage := 45.0

func activate(caster: Node, target_point: Vector3) -> bool:
	var body := caster as Character
	if body == null or not body.is_alive():
		return false
	var scene := body.get_tree().current_scene
	var caster_team := body.team
	var t: Telegraph = Telegraph.show_circle(scene, target_point, radius, windup)
	t.fired.connect(func():
		AudioManager.play_sfx("explosion", -8.0)
		for node in scene.get_tree().get_nodes_in_group("characters"):
			var c := node as Character
			if c == null or not is_instance_valid(c) or not c.is_alive():
				continue
			if not Factions.hostile(caster_team, c.team):
				continue
			if t.contains(c.global_position):
				c.receive_damage(damage,
					body if is_instance_valid(body) else null))
	return true
