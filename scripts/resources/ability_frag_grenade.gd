## Frag grenade — the M1 gear-driven ability. Lobs a grenade in an arc to the
## target point, telegraphs the blast circle during the fuse, then damages
## every living opposing-team character inside the circle. AoE ignores cover
## on purpose: grenades are the counterplay to a dug-in target.
class_name FragGrenadeAbility
extends Ability

@export var throw_range := 14.0
@export var blast_radius := 3.0
## Airtime + telegraph fuse — total reaction window once the arc starts.
@export var flight_secs := 0.55
@export var fuse_secs := 0.8
@export var damage := 55.0

func activate(caster: Node, target_point: Vector3) -> bool:
	var body := caster as Character
	if body == null:
		return false
	var origin := body.muzzle_position()
	var flat := target_point - body.global_position
	flat.y = 0.0
	if flat.length() > throw_range:
		target_point = body.global_position + flat.normalized() * throw_range
	target_point.y = body.global_position.y
	var scene := body.get_tree().current_scene
	_lob(scene, body, origin, target_point)
	return true

func _lob(scene: Node, thrower: Character, from: Vector3, to: Vector3) -> void:
	var nade := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.3, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.15)
	mat.emission_energy_multiplier = 1.5
	sphere.material = mat
	nade.mesh = sphere
	scene.add_child(nade)
	nade.global_position = from
	# Parabolic arc: linear XZ tween + a peaked Y tween on top.
	var apex := maxf(from.y, to.y) + 2.2
	var tw := nade.create_tween()
	tw.set_parallel(true)
	tw.tween_property(nade, "global_position:x", to.x, flight_secs)
	tw.tween_property(nade, "global_position:z", to.z, flight_secs)
	tw.tween_property(nade, "global_position:y", apex, flight_secs * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(nade, "global_position:y", to.y + 0.1, flight_secs * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func(): _land(scene, thrower, nade, to))

func _land(scene: Node, thrower: Character, nade: Node3D, at: Vector3) -> void:
	var telegraph = Telegraph.show_circle(scene, at, blast_radius, fuse_secs)
	telegraph.fired.connect(func():
		if is_instance_valid(nade):
			nade.queue_free()
		Vfx.explosion(scene, at, blast_radius)
		Juice.hit_stop(scene.get_tree(), 0.04, 0.1)
		var enemy_team := 1 - thrower.team
		for body in scene.get_tree().get_nodes_in_group("team_%d" % enemy_team):
			var target := body as Character
			if target == null or not target.is_alive():
				continue
			if telegraph.contains(target.global_position):
				DamageNumber.hit(scene, target.global_position, int(damage))
				target.receive_damage(damage, thrower)
		# Blasts batter breach doors too — grenades are the loud way in.
		for door in scene.get_tree().get_nodes_in_group("breach_doors"):
			if door is BreachDoor and telegraph.contains((door as Node3D).global_position):
				(door as BreachDoor).receive_damage(damage))
