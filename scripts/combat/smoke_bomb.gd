## A smoke bomb: a temporary COVER-layer volume plus the cloud that sells it.
##
## The trick is that smoke is just cover with a timer. Every LOS test in the
## game — Cover.exposure, can_hit, the AI's sight checks — raycasts
## against Layers.COVER, so a sphere on that layer genuinely blinds
## everyone, player and AI alike, with no special cases anywhere. It is NOT
## in the navmesh source group, so nobody paths around it: you can walk
## straight through the cloud you cannot see through.
##
## The clan throws these to break the line they are standing in, then moves —
## leaving your last-known-position on them stale, which is exactly what the
## awareness system already punishes.
class_name SmokeBomb
extends Node3D

const RADIUS := 3.2
const LIFETIME := 6.0
const FADE := 1.2

static func pop(scene: Node, pos: Vector3) -> SmokeBomb:
	if scene == null:
		return null
	var bomb := SmokeBomb.new()
	scene.add_child(bomb)
	bomb.global_position = pos
	bomb._build()
	return bomb

var _blocker: StaticBody3D

func _build() -> void:
	AudioManager.play_sfx("shield_hit", -6.0, 0.2)  # the pop/hiss
	_blocker = StaticBody3D.new()
	_blocker.collision_layer = Layers.COVER
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	col.shape = sphere
	_blocker.add_child(col)
	add_child(_blocker)
	_blocker.position = Vector3(0, RADIUS * 0.6, 0)
	var cloud := CPUParticles3D.new()
	cloud.amount = 26
	cloud.lifetime = LIFETIME * 0.55
	cloud.preprocess = 0.6
	cloud.explosiveness = 0.35
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 2.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.72, 0.74, 0.80, 0.5)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	cloud.mesh = quad
	cloud.direction = Vector3.UP
	cloud.spread = 60.0
	cloud.gravity = Vector3(0, 0.25, 0)
	cloud.initial_velocity_min = 0.4
	cloud.initial_velocity_max = 1.4
	cloud.scale_amount_min = 1.0
	cloud.scale_amount_max = 2.4
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cloud.emission_sphere_radius = RADIUS * 0.7
	add_child(cloud)
	# Blocker dies a beat before the visible cloud does — nobody should be
	# shooting through smoke they can still see.
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(LIFETIME - FADE).timeout
	if is_instance_valid(_blocker):
		_blocker.queue_free()
	cloud.emitting = false
	await tree.create_timer(FADE + cloud.lifetime).timeout
	queue_free()
