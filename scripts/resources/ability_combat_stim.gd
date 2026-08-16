## Combat Stim — a self-cast burst: patch the holes and move faster for a
## few seconds. The crew's answer to being caught in the open.
##
## Deliberately heals HP, which nothing else in the game does mid-fight
## (shields regenerate, HP does not), so this is the one button that buys
## back a mistake. Short window, long cooldown.
class_name CombatStimAbility
extends Ability

@export var heal := 45.0
@export var speed_bonus := 1.35
@export var duration := 5.0

func activate(caster: Node, _target_point: Vector3) -> bool:
	var body := caster as Character
	if body == null or not body.is_alive():
		return false
	body.hp = minf(body.max_hp, body.hp + heal)
	body.hp_changed.emit(body.hp, body.max_hp)
	body.stim_until_ms = Time.get_ticks_msec() + int(duration * 1000.0)
	body.stim_speed_mult = speed_bonus
	Telegraph.show_circle(body.get_tree().current_scene, body.global_position, 1.6,
		0.3, Color(0.4, 1.0, 0.6, 0.30))
	AudioManager.play_sfx("heal", 1.0)
	return true
