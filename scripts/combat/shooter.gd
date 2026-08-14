## Per-character firing component (child node "Shooter" of Character).
## Owns the fire-rate clock and per-shot resolution:
##   hit chance = base accuracy × moving penalty × cover tier × range falloff
## There is no hard range cap — `fire_range` is the weapon's OPTIMAL range,
## full accuracy inside it and hyperbolic falloff beyond (2× range → half
## accuracy), floored so a desperate long shot is never literally impossible.
## Every shot taken announces the shooter to its target (return-fire alert).
## Feel doctrine (from wayfarer): player-team hitscan resolves instantly —
## snappy; PROJECTILE mode has travel time — reactable. Misses render as a
## deflected tracer past the target so the read is honest.
class_name Shooter
extends Node

const MISS_DEFLECT_M := 1.6   # how far wide a missed tracer lands
const RANGE_FALLOFF_FLOOR := 0.05
const HEARING_RADIUS := 14.0  # gunfire is loud — enemies this close aggro

var character: Character
## Whether the most recently resolved shot connected — AI reads this to tell
## "suppressing a covered target" from "actually landing damage".
var last_shot_hit := false
var _next_shot_ms := 0
## slot index → rounds left in that slot's magazine (lazily filled).
var _mag: Dictionary = {}
var _reload_done_ms := 0
var _reload_started_ms := 0

func _ready() -> void:
	character = get_parent() as Character

func gear() -> GearItem:
	return character.active_gear() if character != null else null

# ── Ammo (reserves are infinite; magazines are not) ──────────────────────────

func mag_left(slot: int) -> int:
	var g: GearItem = character.gear_slots[slot]
	if g == null or g.mag_size <= 0:
		return -1  # no ammo system on this gear
	if not _mag.has(slot):
		_mag[slot] = g.mag_size
	return _mag[slot]

func is_reloading() -> bool:
	return Time.get_ticks_msec() < _reload_done_ms

## 0 → 1 over the reload; 0 when not reloading. HUD sweep + AI pacing.
func reload_frac() -> float:
	if not is_reloading():
		return 0.0
	var total := maxf(float(_reload_done_ms - _reload_started_ms), 1.0)
	return clampf((_reload_done_ms - Time.get_ticks_msec()) / total, 0.0, 1.0)

## Begin reloading the active slot (no-op if full, ammo-less, or in progress).
func start_reload() -> void:
	var g := gear()
	if g == null or g.mag_size <= 0 or is_reloading():
		return
	if mag_left(character.active_slot) >= g.mag_size:
		return
	_reload_started_ms = Time.get_ticks_msec()
	_reload_done_ms = _reload_started_ms + int(g.reload_secs * 1000.0)
	AudioManager.play_sfx("reload")
	# The magazine refills when the timer lapses — checked lazily on fire.

func _finish_reload_if_due() -> void:
	if _reload_done_ms > 0 and not is_reloading():
		var g := gear()
		if g != null and g.mag_size > 0:
			_mag[character.active_slot] = g.mag_size
		_reload_done_ms = 0

func can_fire(target: Character) -> bool:
	var g := gear()
	if g == null or character == null or not character.is_alive():
		return false
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return false
	if Time.get_ticks_msec() < _next_shot_ms:
		return false
	if is_reloading():
		return false
	_finish_reload_if_due()
	return Cover.can_hit(character.muzzle_position(), target)

## 1.0 inside the weapon's optimal range, fire_range/distance beyond it.
func range_falloff(g: GearItem, target: Character) -> float:
	var distance := character.global_position.distance_to(target.global_position)
	if distance <= g.fire_range:
		return 1.0
	return maxf(g.fire_range / distance, RANGE_FALLOFF_FLOOR)

## Attempt one shot at `target`. Returns true if a shot was actually taken
## (hit or miss); false if gated by fire rate / range / full cover.
func try_fire(target: Character) -> bool:
	if not can_fire(target):
		return false
	var g := gear()
	if g.heals:
		return false  # heal beams never fire in anger (try_heal is their path)
	if g.fire_mode == GearItem.FireMode.THROWN:
		# Thrown gear routes through its ability (grenade belt et al).
		if g.abilities.is_empty():
			return false
		return character.activate_ability(g.abilities[0], target.global_position)
	if g.fire_mode == GearItem.FireMode.MELEE:
		return _swing(target, g)
	_next_shot_ms = Time.get_ticks_msec() + int(1000.0 / maxf(g.fire_rate, 0.1))
	if g.mag_size > 0:
		var slot := character.active_slot
		_mag[slot] = mag_left(slot) - 1
		if _mag[slot] <= 0:
			start_reload()  # auto-reload on empty; this shot still fires
	AudioManager.play_sfx(g.shot_sfx)
	var muzzle := character.muzzle_position()
	Vfx.muzzle_flash(get_tree().current_scene, muzzle)
	var moving := Vector2(character.velocity.x, character.velocity.z).length() > 0.5
	var accuracy := g.base_accuracy \
		* (g.moving_accuracy_mult if moving else 1.0) \
		* Cover.accuracy_mult(Cover.exposure(muzzle, target)) \
		* range_falloff(g, target)
	var hit := randf() < accuracy
	last_shot_hit = hit
	match g.fire_mode:
		GearItem.FireMode.HITSCAN:
			_resolve_hitscan(target, muzzle, hit, g)
		GearItem.FireMode.PROJECTILE:
			_fire_projectile(target, muzzle, hit, g)
	# Muzzle flash gives the shooter away — hit or miss, the target knows —
	# and gunfire carries: anyone hostile in earshot wakes up.
	target.notify_shot_at(character)
	_alert_hearing()
	return true

## One melee swing at a target already inside reach (can_fire gated the rate
## and full-cover cases). Steel is QUIET: the victim knows — receive_damage
## pins the attacker — but there is no muzzle flash and no bang, so no
## hearing alert, no shot_fired, no turf heat. That silence is the whole
## identity of the melee factions to come.
func _swing(target: Character, g: GearItem) -> bool:
	if character.global_position.distance_to(target.global_position) > g.fire_range:
		return false
	_next_shot_ms = Time.get_ticks_msec() + int(1000.0 / maxf(g.fire_rate, 0.1))
	AudioManager.play_sfx(g.shot_sfx)  # the whoosh
	CharacterAnimator.oneshot(character, "attack", 1.5, 0.55)
	var moving := Vector2(character.velocity.x, character.velocity.z).length() > 0.5
	var accuracy := g.base_accuracy * (g.moving_accuracy_mult if moving else 1.0)
	var hit := randf() < accuracy
	last_shot_hit = hit
	if hit:
		AudioManager.play_sfx("slash")
		Juice.impact_burst(get_tree().current_scene,
			target.global_position + Vector3(0, 1.0 * Character.VERTICAL_SQUASH, 0),
			Color(0.9, 0.25, 0.2))
		target.receive_damage(g.damage * character.damage_mult, character)
	else:
		target.notify_shot_at(character)  # they still saw the lunge
	return true

## Fire with nobody on the line — the round still leaves the gun (rate, mag,
## flash, tracer into the dark) and the noise still carries. Cursor-direction
## shooting calls this when the aim cone is empty.
func fire_wild(at_point: Vector3) -> bool:
	var g := gear()
	if g == null or character == null or not character.is_alive():
		return false
	if g.fire_mode == GearItem.FireMode.THROWN or g.heals:
		return false
	if Time.get_ticks_msec() < _next_shot_ms or is_reloading():
		return false
	_finish_reload_if_due()
	if g.fire_mode == GearItem.FireMode.MELEE:
		# Swing at the air — whoosh and follow-through, nothing else.
		_next_shot_ms = Time.get_ticks_msec() + int(1000.0 / maxf(g.fire_rate, 0.1))
		AudioManager.play_sfx(g.shot_sfx)
		CharacterAnimator.oneshot(character, "attack", 1.5, 0.55)
		return true
	_next_shot_ms = Time.get_ticks_msec() + int(1000.0 / maxf(g.fire_rate, 0.1))
	if g.mag_size > 0:
		var slot := character.active_slot
		_mag[slot] = mag_left(slot) - 1
		if _mag[slot] <= 0:
			start_reload()
	AudioManager.play_sfx(g.shot_sfx)
	var muzzle := character.muzzle_position()
	Vfx.muzzle_flash(get_tree().current_scene, muzzle)
	var flat := at_point - character.global_position
	flat.y = 0.0
	var reach := maxf(flat.length(), g.fire_range)
	var toward: Vector3 = character.global_position + flat.normalized() * reach \
		+ Vector3(0, 1.3 * Character.VERTICAL_SQUASH, 0)
	# Wild rounds hit the world: cover geometry stops the tracer, and breach
	# doors take the damage.
	var query := PhysicsRayQueryParameters3D.create(muzzle, toward, Layers.LOS_MASK)
	var hit := character.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		toward = hit["position"]
		if hit["collider"] is BreachDoor:
			(hit["collider"] as BreachDoor).receive_damage(g.damage)
	Vfx.tracer(get_tree().current_scene, muzzle, toward)
	_alert_hearing()
	return true

func _alert_hearing() -> void:
	GameState.shot_fired.emit(character)
	for node in get_tree().get_nodes_in_group("characters"):
		var enemy := node as Character
		if enemy == null or enemy.team == character.team or not enemy.is_alive():
			continue
		if character.global_position.distance_to(enemy.global_position) > HEARING_RADIUS:
			continue
		# Type-scan, not a name lookup — controllers are attached in code and
		# not every call site names the node.
		for child in enemy.get_children():
			if child is EnemyController:
				# Noise gives a position to investigate, not a target lock.
				(child as EnemyController).heard(character.global_position)
				break

func _resolve_hitscan(target: Character, muzzle: Vector3, hit: bool, g: GearItem) -> void:
	var scene := get_tree().current_scene
	var chest: Vector3 = target.global_position + Vector3(0, 1.3, 0)
	if hit:
		Vfx.tracer(scene, muzzle, chest)
		Juice.impact_burst(scene, target.global_position)
		DamageNumber.hit(scene, target.global_position, int(g.damage))
		target.receive_damage(g.damage * character.damage_mult, character)
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
			body.receive_damage(g.damage * character.damage_mult, character),
		g.projectile_speed)

## Heal-gun path: beam a squadmate back up. Needs LOS and optimal range (no
## falloff — the beam either connects or it doesn't), always "hits", and runs
## on the same fire-rate/magazine clocks as any other gun.
func try_heal(mate: Character) -> bool:
	var g := gear()
	if g == null or not g.heals or character == null or not character.is_alive():
		return false
	if mate == null or not is_instance_valid(mate) or not mate.is_alive():
		return false
	if mate.team != character.team or mate == character:
		return false
	# HP healer refuses the healthy; a shield mender refuses the charged.
	if g.restores_shield:
		if mate.max_shield <= 0.0 or mate.shield >= mate.max_shield:
			return false
	elif mate.hp >= mate.max_hp:
		return false
	if Time.get_ticks_msec() < _next_shot_ms or is_reloading():
		return false
	_finish_reload_if_due()
	if character.global_position.distance_to(mate.global_position) > g.fire_range:
		return false
	var muzzle := character.muzzle_position()
	if not Cover.can_hit(muzzle, mate):
		return false
	_next_shot_ms = Time.get_ticks_msec() + int(1000.0 / maxf(g.fire_rate, 0.1))
	if g.mag_size > 0:
		var slot := character.active_slot
		_mag[slot] = mag_left(slot) - 1
		if _mag[slot] <= 0:
			start_reload()
	AudioManager.play_sfx(g.shot_sfx)
	var scene := get_tree().current_scene
	Vfx.tracer(scene, muzzle, mate.global_position + Vector3(0, 1.3 * Character.VERTICAL_SQUASH, 0),
		Color(0.35, 1.0, 0.55))
	if g.restores_shield:
		DamageNumber.spawn(scene, mate.global_position, "+%d" % int(g.damage),
			Color(0.5, 0.8, 1.0))
		mate.receive_shield_charge(g.damage * character.damage_mult)
	else:
		DamageNumber.spawn(scene, mate.global_position, "+%d" % int(g.damage),
			Color(0.4, 1.0, 0.55))
		mate.receive_heal(g.damage * character.damage_mult)
	return true

## A point past the target, pushed sideways — where the missed shot "went".
func _deflected(from: Vector3, toward: Vector3) -> Vector3:
	var dir := (toward - from).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	return toward + dir * 1.5 + side * randf_range(-MISS_DEFLECT_M, MISS_DEFLECT_M)
