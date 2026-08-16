## Smoke Screen — drop a blinding cloud at the cursor.
##
## Reuses SmokeBomb wholesale, which is the point: smoke in this game is just
## COVER with a timer, and every LOS test already raycasts Layers.COVER. So
## the cloud blinds the AI exactly as hard as it blinds the player, with no
## special cases — and it makes the clan's signature trick something the crew
## can answer in kind.
class_name SmokeScreenAbility
extends Ability

@export var throw_range := 13.0

func activate(caster: Node, target_point: Vector3) -> bool:
	var body := caster as Character
	if body == null:
		return false
	var flat := target_point - body.global_position
	flat.y = 0.0
	if flat.length() > throw_range:
		target_point = body.global_position + flat.normalized() * throw_range
	target_point.y = body.global_position.y
	SmokeBomb.pop(body.get_tree().current_scene, target_point)
	AudioManager.play_sfx("swing", -2.0)
	return true
