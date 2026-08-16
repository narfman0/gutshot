## A sabotage job's target — an installation the crew has to wreck.
##
## Extends BreachDoor rather than reimplementing destructibility, because the
## two damage paths in the game both key off that type: Shooter's wild-fire
## raycast checks `is BreachDoor`, and the frag grenade sweeps the
## "breach_doors" group. Inheriting means bullets AND explosives hurt this
## for free, and `breached` already fires before the node frees itself.
##
## The dressing is the difference: a squat humming core with warning lamps,
## not a roller door.
class_name JobSabotage
extends BreachDoor

const CORE_HP := 320.0

static func build_objective(chunk: SiteChunk, job: Dictionary) -> JobSabotage:
	var core := JobSabotage.new()
	core.collision_layer = Layers.COVER
	core.add_to_group("breach_doors")   # frag grenades sweep this group
	core.add_to_group(NavRuntime.SOURCE_GROUP)
	core.name = "JobSabotage"
	core.hp = CORE_HP
	core.max_hp = CORE_HP
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.6, 2.4)
	col.shape = box
	col.position.y = 1.3
	core.add_child(col)
	core._dress(job)
	chunk.add_child(core)
	core.position = job.get("pos", Vector3.ZERO)
	return core

## Deliberately loud — this is an objective, not scenery. The lamp and the
## label are how a player picks it out of a dressed site.
func _dress(job: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.4, 2.6, 2.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.17, 0.19)
	mat.metallic = 0.6
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.95, 1.0)
	mat.emission_energy_multiplier = 0.9
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = 1.3
	add_child(mi)

	var tag := Label3D.new()
	tag.text = str(job.get("loot", "TARGET"))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 34
	tag.pixel_size = 0.004
	tag.outline_size = 8
	tag.modulate = Color(0.4, 0.95, 1.0)
	tag.position.y = 3.2
	add_child(tag)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.35, 0.9, 1.0)
	lamp.light_energy = 1.6
	lamp.omni_range = 6.0
	lamp.position.y = 2.2
	add_child(lamp)
