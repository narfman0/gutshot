## Headless AI probe — run with:
##   godot --headless res://future/tests/harnesses/ai_probe.tscn
## Builds a tiny arena (ground + one crate) with a runtime-baked navmesh and
## asserts the CombatBrain: (1) an engaged enemy repositions behind cover so
## its exposure to the threat drops to the full-cover tier; (2) a
## damage-starved enemy leaves cover and swings around the flank arc.
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

func _ready() -> void:
	# Ground: static collider on the ground layer, parsed into the navmesh.
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.GROUND
	var gshape := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(40, 0.5, 40)
	gshape.shape = gbox
	ground.add_child(gshape)
	ground.add_to_group("navigation_mesh_source_group")
	add_child(ground)
	ground.global_position = Vector3(0, -0.25, 0)

	# One full-height crate the enemy should hide behind.
	var crate := StaticBody3D.new()
	crate.collision_layer = Layers.COVER
	crate.add_to_group("cover")
	var cshape := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(2.0, 2.2, 2.0)
	cshape.shape = cbox
	crate.add_child(cshape)
	crate.add_to_group("navigation_mesh_source_group")
	add_child(crate)
	crate.global_position = Vector3(0, 1.1, -6)

	# Bake + register the navmesh at runtime (see NavRuntime for the server-
	# level registration rationale).
	await get_tree().physics_frame
	await get_tree().physics_frame
	NavRuntime.bake(self, Layers.GROUND | Layers.COVER)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Threat (player team) and an armed enemy in the open.
	var threat := _make_character(0, Vector3(0, 0.1, 4))
	var enemy := _make_character(1, Vector3(4, 0.1, -8))
	var gun := GearItem.new()
	gun.damage = 1.0
	gun.fire_range = 20.0
	gun.fire_rate = 2.0
	gun.base_accuracy = 0.0  # never actually hits — keeps the threat alive
	enemy.equip(gun)
	var brain := CombatBrain.new()
	brain.name = "CombatBrain"
	enemy.add_child(brain)
	var controller := EnemyController.new()
	controller.aggro_radius = 30.0
	enemy.add_child(controller)
	await get_tree().physics_frame

	var exposed_start := Cover.exposure(threat.muzzle_position(), enemy)
	_check(exposed_start > Cover.EXPOSED_MIN,
		"enemy starts exposed (%.2f)" % exposed_start)

	# 1. Give the brain a few seconds to reach cover.
	var covered := false
	for i in 100:  # up to ~5 s of physics frames at 20/s polls
		await get_tree().create_timer(0.05).timeout
		if Cover.exposure(threat.muzzle_position(), enemy) <= Cover.FULL_COVER_MAX \
				and brain.state != CombatBrain.State.ADVANCE:
			covered = true
			break
	_check(covered, "enemy reached full cover from the threat (exposure %.2f, state %d)"
		% [Cover.exposure(threat.muzzle_position(), enemy), brain.state])

	# 2. Starve it: the threat never takes damage (accuracy 0), so after
	#    FLANK_TRIGGER_SECS the brain must enter FLANK and change its bearing
	#    to the threat.
	var bearing_start: float = _bearing(threat, enemy)
	var flanked := false
	var deadline := CombatBrain.FLANK_TRIGGER_SECS + 6.0
	var waited := 0.0
	while waited < deadline:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
		if brain.state == CombatBrain.State.FLANK:
			flanked = true
			break
	_check(flanked, "damage-starved brain entered FLANK")
	if flanked:
		# Track the swing while it travels — it may resettle into new cover
		# afterward, so the peak angle is the honest measure.
		var max_swing := 0.0
		for i in 80:
			await get_tree().create_timer(0.1).timeout
			var swing: float = absf(angle_difference(bearing_start, _bearing(threat, enemy)))
			max_swing = maxf(max_swing, swing)
			if max_swing > deg_to_rad(30.0):
				break
		_check(max_swing > deg_to_rad(30.0),
			"flank changed bearing by %.0f°" % rad_to_deg(max_swing))

	if _failures.is_empty():
		print("AI_PROBE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("AI_PROBE: %d FAILURES" % _failures.size())
		get_tree().quit(1)

func _bearing(from: Character, to: Character) -> float:
	var d := to.global_position - from.global_position
	return atan2(d.z, d.x)
