## Focus Fire — a squad COMMAND rather than a weapon.
##
## Points every living follower at whatever the cursor is over: pins it as
## their threat with a fresh last-known position, which is precisely what a
## muzzle flash does to them already. So this needs no new AI — it reaches
## into the awareness system the followers were built on and pulls the
## trigger on it.
##
## The verb the crew never had: the player can aim, and can shoot, but until
## now could not ORDER. Squad tactics with one key.
class_name FocusFireAbility
extends Ability

@export var command_range := 30.0
## How wide a cone around the aim line still counts as "that one".
@export var acquire_cone_deg := 18.0

func activate(caster: Node, target_point: Vector3) -> bool:
	var body := caster as Character
	if body == null:
		return false
	var mark := _acquire(body, target_point)
	if mark == null:
		return false
	var ordered := 0
	for member in GameState.squad:
		var mate := member as Character
		if mate == null or mate == body or not is_instance_valid(mate) or not mate.is_alive():
			continue
		var brain := mate.get_node_or_null("CombatBrain") as CombatBrain
		if brain == null:
			continue
		brain.pin_threat(mark)
		ordered += 1
	if ordered == 0:
		return false
	Telegraph.show_circle(body.get_tree().current_scene, mark.global_position, 1.2,
		0.45, Color(1.0, 0.35, 0.3, 0.30))
	AudioManager.play_sfx("select", -1.0)
	return true

## Nearest hostile along the aim line — the same soft-acquire shape the
## player's own fire uses, so the command lands where they think it will.
func _acquire(body: Character, target_point: Vector3) -> Character:
	var aim := target_point - body.global_position
	aim.y = 0.0
	if aim.length_squared() < 0.01:
		return null
	aim = aim.normalized()
	var best: Character = null
	var best_d := command_range
	for node in Factions.hostiles_of(body.get_tree(), body.team):
		var foe := node as Character
		if foe == null or not is_instance_valid(foe) or not foe.is_alive():
			continue
		var to := foe.global_position - body.global_position
		to.y = 0.0
		var d := to.length()
		if d > best_d or d < 0.01:
			continue
		if rad_to_deg(aim.angle_to(to.normalized())) > acquire_cone_deg:
			continue
		best = foe
		best_d = d
	return best
