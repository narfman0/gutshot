## Headless combat smoke — run with:
##   godot --headless res://future/tests/harnesses/combat_smoke.tscn
## Exercises shooting, tiered cover exposure, run-and-gun accuracy penalty,
## and the grenade's ignore-cover AoE on a bare physics world.
extends Node3D

const CharacterScene = preload("res://scenes/characters/character.tscn")

var _failures: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _make_character(team: int, pos: Vector3) -> Character:
	var c: Character = CharacterScene.instantiate()
	c.team = team
	add_child(c)
	c.global_position = pos
	return c

func _make_cover_box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.COVER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = pos
	return body

func _perfect_smg() -> GearItem:
	var g := GearItem.new()
	g.display_name = "TestSMG"
	g.fire_mode = GearItem.FireMode.HITSCAN
	g.damage = 10.0
	g.fire_range = 30.0
	g.fire_rate = 100000.0  # effectively ungated for the loop tests
	g.base_accuracy = 1.0
	g.moving_accuracy_mult = 0.0  # moving → guaranteed miss (deterministic)
	return g

func _ready() -> void:
	var shooter_char := _make_character(0, Vector3.ZERO)
	var target := _make_character(1, Vector3(0, 0, -8))
	shooter_char.equip(_perfect_smg())
	var shooter: Shooter = shooter_char.get_node("Shooter")
	await get_tree().physics_frame
	await get_tree().physics_frame

	# 1. Open ground, perfect accuracy, standing: every shot lands.
	var hp0 := target.hp
	for i in 5:
		_check(shooter.try_fire(target), "open-ground shot %d taken" % i)
	_check(is_equal_approx(target.hp, hp0 - 50.0),
		"5 perfect shots deal 50 (hp %.1f -> %.1f)" % [hp0, target.hp])

	# 2. Chest-high cover adjacent to the target: half-cover band, -50% accuracy.
	#    Box heights scale with the world's vertical squash so the tier
	#    geometry matches the squashed body sample points.
	var squash := Character.VERTICAL_SQUASH
	var half_box := _make_cover_box(Vector3(0, 0.7 * squash, -7),
		Vector3(2.0, 1.4 * squash, 0.4))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var exposure := Cover.exposure(shooter_char.muzzle_position(), target)
	_check(exposure > Cover.FULL_COVER_MAX and exposure < Cover.EXPOSED_MIN,
		"chest-high box gives half cover (exposure %.2f)" % exposure)
	_check(is_equal_approx(Cover.accuracy_mult(exposure), Cover.HALF_COVER_MULT),
		"half cover halves accuracy")

	# 3. Full-height wall: full cover, shot refused.
	half_box.free()
	_make_cover_box(Vector3(0, 1.1 * squash, -7), Vector3(2.4, 2.2 * squash, 0.4))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var walled := Cover.exposure(shooter_char.muzzle_position(), target)
	_check(walled <= Cover.FULL_COVER_MAX, "full wall blocks all rays (exposure %.2f)" % walled)
	_check(not shooter.try_fire(target), "shot refused through full cover")

	# 4. Run-and-gun penalty: moving_accuracy_mult 0 → every moving shot misses.
	#    (Sidestep so the wall from step 3 isn't between them.)
	shooter_char.global_position = Vector3(6, 0, 0)
	target.global_position = Vector3(6, 0, -8)
	shooter_char.velocity = Vector3(5, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp_before := target.hp
	for i in 5:
		shooter.try_fire(target)
	_check(is_equal_approx(target.hp, hp_before),
		"all moving shots missed (mult 0) (hp %.1f -> %.1f)" % [hp_before, target.hp])
	shooter_char.velocity = Vector3.ZERO

	# 5. Grenade kills through full cover: wall the target off, lob over it.
	target.global_position = Vector3(0, 0, -7.8)
	shooter_char.global_position = Vector3.ZERO
	await get_tree().physics_frame
	_check(Cover.exposure(shooter_char.muzzle_position(), target) <= Cover.FULL_COVER_MAX,
		"target back behind the wall for the grenade test")
	var frag: FragGrenadeAbility = load("res://resources/abilities/frag_grenade.tres")
	var hp_pre_nade := target.hp
	_check(frag.activate(shooter_char, target.global_position), "grenade cast starts")
	await get_tree().create_timer(frag.flight_secs + frag.fuse_secs + 0.6).timeout
	_check(target.hp < hp_pre_nade,
		"grenade damages behind cover (hp %.1f -> %.1f)" % [hp_pre_nade, target.hp])

	# 6. Shields absorb before HP; crew go DOWN and a nearby mate revives them.
	var shielded := _make_character(0, Vector3(12, 0, 0))
	shielded.max_shield = 30.0
	shielded.shield = 30.0
	var hp_before_shield := shielded.hp
	shielded.receive_damage(20.0)
	_check(is_equal_approx(shielded.shield, 10.0) and is_equal_approx(shielded.hp, hp_before_shield),
		"shield absorbs damage first (shield %.0f hp %.0f)" % [shielded.shield, shielded.hp])
	shielded.receive_damage(30.0)
	_check(is_equal_approx(shielded.shield, 0.0) and shielded.hp < hp_before_shield,
		"overflow damage bleeds into hp (shield %.0f hp %.0f)" % [shielded.shield, shielded.hp])

	# Heal gun: beams a wounded squadmate back up, refuses enemies and full-hp.
	var mate := _make_character(0, Vector3(13, 0, 0))
	var heal_gun: GearItem = load("res://resources/gear/heal_gun.tres")
	mate.equip(heal_gun)
	mate.select_slot(1)
	var medic_shooter: Shooter = mate.get_node("Shooter")
	var hurt_hp := shielded.hp
	_check(medic_shooter.try_heal(shielded), "heal gun beams a wounded mate")
	_check(shielded.hp > hurt_hp, "heal restored hp (%.0f -> %.0f)" % [hurt_hp, shielded.hp])
	_check(not medic_shooter.try_heal(target), "heal gun refuses enemies")

	shielded.receive_damage(9999.0)
	_check(shielded.downed and not shielded.is_alive(), "crew at 0 hp goes DOWN, not dead")
	await get_tree().create_timer(Character.REVIVE_SECS + 0.6).timeout
	_check(not shielded.downed and shielded.is_alive()
		and is_equal_approx(shielded.hp, shielded.max_hp * Character.REVIVE_HP_FRAC),
		"nearby mate revives at %.0f%% hp (downed=%s hp=%.0f)"
		% [Character.REVIVE_HP_FRAC * 100.0, shielded.downed, shielded.hp])
	mate.free()

	if _failures.is_empty():
		print("COMBAT_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("COMBAT_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
