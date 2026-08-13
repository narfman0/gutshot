## Dodgeable projectile: flies in a straight line toward where the target WAS
## at fire time, so strafing sidesteps it — travel time is the counterplay.
## On overlapping any living body of the opposing team it hands that body to
## `on_hit` (the shooter resolves damage) and frees itself.
class_name Projectile
extends Node3D

const HIT_RADIUS := 0.55  # metres, XZ
const MAX_LIFE := 2.5     # seconds before fizzling

## func(body: Character) -> void — resolve the hit on this body.
var on_hit: Callable
var speed := 18.0
var target_team := 0

var _dir: Vector3 = Vector3.FORWARD
var _age: float = 0.0

# (Untyped return: a class_name can't reference itself in static methods —
# Godot 4.7 limitation.)
static func fire(parent: Node, from: Vector3, toward: Vector3, team_to_hit: int,
		hit_cb: Callable, fly_speed := 18.0, color := Color(0.55, 0.95, 1.0)):
	var p = load("res://scripts/combat/projectile.gd").new()
	p.on_hit = hit_cb
	p.speed = fly_speed
	p.target_team = team_to_hit
	parent.add_child(p)
	p.global_position = from
	var d := toward - from
	d.y = 0.0
	p._dir = d.normalized() if d.length_squared() > 0.0001 else Vector3.FORWARD
	p._add_visual(color)
	return p

func _physics_process(delta: float) -> void:
	_age += delta
	if _age > MAX_LIFE:
		queue_free()
		return
	global_position += _dir * speed * delta
	for body in get_tree().get_nodes_in_group("team_%d" % target_team):
		if not (body is Character) or not (body as Character).is_alive():
			continue
		var to_body: Vector3 = (body as Node3D).global_position - global_position
		if absf(to_body.y) > 1.6:
			continue
		to_body.y = 0.0
		if to_body.length() <= HIT_RADIUS:
			if on_hit.is_valid():
				on_hit.call(body)
			queue_free()
			return

func _add_visual(color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	sphere.material = mat
	mi.mesh = sphere
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.6
	light.omni_range = 2.0
	add_child(light)
