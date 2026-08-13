## A destructible door — blocks movement, LOS, and the navmesh until shot or
## blasted open. Wild gunfire (Shooter.fire_wild raycasts cover geometry) and
## grenade blasts damage it; at 0 HP it blows out and asks the level to
## re-bake navigation, opening the path.
class_name BreachDoor
extends StaticBody3D

signal breached

@export var hp := 80.0

var _mesh: MeshInstance3D

## Build a door filling a gap: `size` is the door slab (x = width across the
## gap, y = height, z = thickness).
static func build(parent: Node, pos: Vector3, size: Vector3, yaw_deg := 0.0) -> BreachDoor:
	var door := BreachDoor.new()
	door.collision_layer = Layers.COVER
	door.add_to_group("breach_doors")
	door.add_to_group(NavRuntime.SOURCE_GROUP)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position.y = size.y * 0.5
	door.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.33, 0.12)  # hazard-yellow roller slab
	mat.roughness = 0.6
	mat.metallic = 0.4
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.55, 0.1)
	mat.emission_energy_multiplier = 0.25
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = size.y * 0.5
	door.add_child(mi)
	door._mesh = mi
	parent.add_child(door)
	door.global_position = pos
	door.rotation.y = deg_to_rad(yaw_deg)
	return door

func receive_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	Juice.impact_burst(get_tree().current_scene, global_position, Color(1.0, 0.7, 0.2))
	# Battered doors glow hotter — a readable damage state.
	if _mesh != null and _mesh.mesh != null:
		var mat := (_mesh.mesh as BoxMesh).material as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = 0.25 + 1.5 * (1.0 - maxf(hp, 0.0) / 80.0)
	if hp <= 0.0:
		_breach()

func _breach() -> void:
	Vfx.explosion(get_tree().current_scene, global_position + Vector3(0, 0.5, 0), 2.0)
	breached.emit()
	# Free first so the rebake parses the world without this collider.
	var tree := get_tree()
	queue_free()
	tree.call_group("nav_owner", "rebake_nav")
