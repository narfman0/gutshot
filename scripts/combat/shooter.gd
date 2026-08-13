## Per-character firing component (child node "Shooter" of Character).
## Owns the fire-rate clock and per-shot resolution:
##   hit chance = weapon base accuracy × moving penalty × cover tier
## Feel doctrine (from wayfarer): player-team hitscan resolves instantly —
## snappy; PROJECTILE mode has travel time — reactable. Misses render as a
## deflected tracer past the target so the read is honest.
class_name Shooter
extends Node

const MISS_DEFLECT_M := 1.6  # how far wide a missed tracer lands

var character: Character
## Whether the most recently resolved shot connected — AI reads this to tell
## "suppressing a covered target" from "actually landing damage".
var last_shot_hit := false
var _next_shot_ms := 0

func _ready() -> void:
	character = get_parent() as Character

func gear() -> GearItem:
	return character.active_gear() if character != null else null

func can_fire(target: Character) -> bool:
	var g := gear()
	if g == null or character == null or not character.is_alive():
		return false
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return false
	if Time.get_ticks_msec() < _next_shot_ms:
		return false
	if character.global_position.distance_to(target.global_position) > g.fire_range:
		return false
	return Cover.can_hit(character.muzzle_position(), target)

## Attempt one shot at `target`. Returns true if a shot was actually taken
## (hit or miss); false if gated by fire rate / range / full cover.
func try_fire(target: Character) -> bool:
	if not can_fire(target):
		return false
	var g := gear()
	if g.fire_mode == GearItem.FireMode.THROWN:
		# Thrown gear routes through its ability (grenade belt et al).
		if g.abilities.is_empty():
			return false
		return character.activate_ability(g.abilities[0], target.global_position)
	_next_shot_ms = Time.get_ticks_msec() + int(1000.0 / maxf(g.fire_rate, 0.1))
	var muzzle := character.muzzle_position()
	Vfx.muzzle_flash(get_tree().current_scene, muzzle)
	var moving := Vector2(character.velocity.x, character.velocity.z).length() > 0.5
	var accuracy := g.base_accuracy \
		* (g.moving_accuracy_mult if moving else 1.0) \
		* Cover.accuracy_mult(Cover.exposure(muzzle, target))
	var hit := randf() < accuracy
	last_shot_hit = hit
	match g.fire_mode:
		GearItem.FireMode.HITSCAN:
			_resolve_hitscan(target, muzzle, hit, g)
		GearItem.FireMode.PROJECTILE:
			_fire_projectile(target, muzzle, hit, g)
	return true

func _resolve_hitscan(target: Character, muzzle: Vector3, hit: bool, g: GearItem) -> void:
	var scene := get_tree().current_scene
	var chest: Vector3 = target.global_position + Vector3(0, 1.3, 0)
	if hit:
		Vfx.tracer(scene, muzzle, chest)
		Juice.impact_burst(scene, target.global_position)
		DamageNumber.hit(scene, target.global_position, int(g.damage))
		target.receive_damage(g.damage, character)
	else:
		Vfx.tracer(scene, muzzle, _deflected(muzzle, chest))
		DamageNumber.miss(scene, target.global_position)

func _fire_projectile(target: Character, muzzle: Vector3, hit: bool, g: GearItem) -> void:
	var aim: Vector3 = target.global_position + Vector3(0, 1.2, 0)
	if not hit:
		aim = _deflected(muzzle, aim)
	Projectile.fire(get_tree().current_scene, muzzle, aim, target.team,
		func(body: Character):
			var scene := get_tree().current_scene
			Juice.impact_burst(scene, body.global_position)
			DamageNumber.hit(scene, body.global_position, int(g.damage))
			body.receive_damage(g.damage, character),
		g.projectile_speed)

## A point past the target, pushed sideways — where the missed shot "went".
func _deflected(from: Vector3, toward: Vector3) -> Vector3:
	var dir := (toward - from).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	return toward + dir * 1.5 + side * randf_range(-MISS_DEFLECT_M, MISS_DEFLECT_M)
