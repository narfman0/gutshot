## A destructible door — blocks movement, LOS, and the navmesh until shot or
## blasted open. Wild gunfire (Shooter.fire_wild raycasts cover geometry) and
## grenade blasts damage it; at 0 HP it blows out and asks the level to
## re-bake navigation, opening the path.
class_name BreachDoor
extends StaticBody3D

signal breached

## Roller-door dressing (full literal for fetch_assets.sh).
const ROLLER_MESH := "res://assets/meshes/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Bld_Door_Roller_Large_01.gltf"

@export var hp := 80.0
var max_hp := 80.0

var _damage_strip_mat: StandardMaterial3D

## Build a door filling a gap: `size` is the door slab (x = width across the
## gap, y = height, z = thickness).
static func build(parent: Node, pos: Vector3, size: Vector3, yaw_deg := 0.0) -> BreachDoor:
	var door := BreachDoor.new()
	door.collision_layer = Layers.COVER
	door.add_to_group("breach_doors")
	door.add_to_group(NavRuntime.SOURCE_GROUP)
	door.max_hp = door.hp
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position.y = size.y * 0.5
	door.add_child(col)
	parent.add_child(door)
	door.global_position = pos
	door.rotation.y = deg_to_rad(yaw_deg)
	door._add_visual(size)
	return door

## Roller-door mesh scaled to fill the gap, plus a damage strip across the
## top that heats up as the door takes fire. Falls back to a plain slab when
## the mesh isn't fetched.
func _add_visual(size: Vector3) -> void:
	var scene = load(ROLLER_MESH)
	var dressed := false
	if scene != null:
		var visual: Node3D = scene.instantiate()
		add_child(visual)
		# Fit: merged AABB in door-local space (carries the cm→m corrective
		# chain), then non-uniform scale to the gap.
		var inv := global_transform.affine_inverse()
		var aabb := AABB()
		var found := false
		for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var mesh_aabb: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
			aabb = mesh_aabb if not found else aabb.merge(mesh_aabb)
			found = true
		if found and aabb.size.x > 0.01 and aabb.size.y > 0.01:
			visual.scale = Vector3(size.x / aabb.size.x,
				size.y / aabb.size.y, minf(1.0, size.z / maxf(aabb.size.z, 0.1)))
			# Re-center the fitted mesh on the gap, base at the floor.
			var fitted := aabb.get_center() * visual.scale
			visual.position = Vector3(-fitted.x, size.y * 0.5 - fitted.y, -fitted.z)
			dressed = true
		else:
			visual.queue_free()
	if not dressed:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.33, 0.12)
		mat.roughness = 0.6
		mat.metallic = 0.4
		mesh.material = mat
		mi.mesh = mesh
		mi.position.y = size.y * 0.5
		add_child(mi)
	# Damage strip: a thin emissive bar over the lintel — cool amber when
	# fresh, blazing as the door nears failure.
	var strip := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(size.x, 0.12, size.z + 0.1)
	_damage_strip_mat = StandardMaterial3D.new()
	_damage_strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_damage_strip_mat.albedo_color = Color(0.9, 0.55, 0.1)
	_damage_strip_mat.emission_enabled = true
	_damage_strip_mat.emission = Color(0.9, 0.55, 0.1)
	_damage_strip_mat.emission_energy_multiplier = 0.3
	bar.material = _damage_strip_mat
	strip.mesh = bar
	strip.position.y = size.y + 0.1
	add_child(strip)
	# Warning lamp: a red pool at the sealed door — dies with the door, so a
	# dark doorway means the way is open.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.25, 0.15)
	lamp.light_energy = 1.4
	lamp.omni_range = 4.5
	lamp.omni_attenuation = 1.6
	lamp.shadow_enabled = false
	lamp.position.y = size.y + 0.4
	add_child(lamp)

func receive_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	Juice.impact_burst(get_tree().current_scene, global_position, Color(1.0, 0.7, 0.2))
	# Battered doors glow hotter — a readable damage state.
	if _damage_strip_mat != null:
		var frac := 1.0 - maxf(hp, 0.0) / max_hp
		_damage_strip_mat.emission_energy_multiplier = 0.3 + 2.2 * frac
		_damage_strip_mat.emission = Color(0.9, 0.55 - 0.35 * frac, 0.1)
	if hp <= 0.0:
		_breach()

func _breach() -> void:
	Vfx.explosion(get_tree().current_scene, global_position + Vector3(0, 0.5, 0), 2.0)
	breached.emit()
	# Free first so the rebake parses the world without this collider.
	var tree := get_tree()
	queue_free()
	tree.call_group("nav_owner", "rebake_nav")
