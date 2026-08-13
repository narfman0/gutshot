## Gunfight VFX — every effect is a fire-and-forget static that builds its
## nodes in code, plays, and frees itself. Sits above juice.gd (hit-stop /
## shake / impact sparks); this file owns the readable shapes: tracers,
## muzzle flashes, explosions.
class_name Vfx
extends RefCounted

## A bright beam from muzzle to endpoint that fades in a few frames — the
## shot's read. Misses get a deflected endpoint from the caller.
static func tracer(scene: Node, from_pos: Vector3, to_pos: Vector3,
		color := Color(1.0, 0.85, 0.45)) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var seg := to_pos - from_pos
	var length := seg.length()
	if length < 0.05:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.012, length)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 2.2
	box.material = mat
	mi.mesh = box
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(mi)
	mi.global_position = (from_pos + to_pos) * 0.5
	mi.look_at(to_pos, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.08)
	tw.tween_callback(mi.queue_free)

## Short-lived glow at the muzzle on every shot.
static func muzzle_flash(scene: Node, pos: Vector3,
		color := Color(1.0, 0.8, 0.4)) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var l := OmniLight3D.new()
	l.light_color = Color(color.r, color.g, color.b)
	l.light_energy = 1.8
	l.omni_range = 2.5
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	scene.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.07)
	tw.tween_callback(l.queue_free)

## Grenade / rocket detonation: flash, fireball puff, spark ring.
static func explosion(scene: Node, pos: Vector3, radius := 3.0,
		color := Color(1.0, 0.55, 0.2)) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	Juice.flash_light(scene, pos, color, 5.0, 0.35)
	AudioManager.play_sfx("explosion", 2.0)
	var p := CPUParticles3D.new()
	# emitting defaults true — hold the burst until the node is positioned or
	# every explosion detonates at the world origin.
	p.emitting = false
	p.one_shot = true
	p.amount = 28
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = radius * 1.6
	p.initial_velocity_max = radius * 3.2
	p.gravity = Vector3(0, -10, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mesh.material = mat
	p.mesh = mesh
	scene.add_child(p)
	p.global_position = pos + Vector3(0, 0.4, 0)
	p.emitting = true
	scene.get_tree().create_timer(p.lifetime + 0.2).timeout.connect(
		func():
			if is_instance_valid(p):
				p.queue_free())
