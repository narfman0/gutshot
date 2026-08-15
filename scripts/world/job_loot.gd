## The thing a retrieval job is about — a glowing pickup dropped inside the
## target interior when the crew accepts the contract.
##
## Deliberately loud: a pulsing emissive box, a floating name and its own
## practical light. The room it sits in has three solid walls and one door,
## so finding it is never the challenge — getting back out with it is.
##
## Only the ACTIVE character can lift it. Followers blunder through doorways
## constantly while pathing, and a job that starts because the medic clipped
## a corner is a job the player didn't choose to start.
class_name JobLoot
extends Area3D

signal lifted

const BOB_HEIGHT := 0.12
const BOB_SPEED := 2.2
const SPIN_SPEED := 1.1

var _world: GameWorld
var _mesh: MeshInstance3D
var _base_y := 0.0
var _t := 0.0

## Build the pickup inside `chunk` at the job's local position.
static func spawn(chunk: SiteChunk, job: Dictionary, world: GameWorld) -> JobLoot:
	var loot := JobLoot.new()
	loot._world = world
	loot.name = "JobLoot"
	loot.collision_layer = 0
	loot.collision_mask = Layers.SQUAD
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.6
	col.shape = shape
	loot.add_child(col)

	loot._mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.6, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.11, 0.09)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.35)
	mat.emission_energy_multiplier = 1.6
	box.material = mat
	loot._mesh.mesh = box
	loot.add_child(loot._mesh)

	var tag := Label3D.new()
	tag.text = str(job.get("loot", "TAKE"))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 34
	tag.pixel_size = 0.004
	tag.outline_size = 8
	tag.modulate = Color(1.0, 0.85, 0.45)
	tag.position.y = 1.1
	loot.add_child(tag)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.4)
	# Enough to find it by, not enough to paint a flat panel on the back wall.
	lamp.light_energy = 1.2
	lamp.omni_range = 3.5
	lamp.position.y = 0.8
	loot.add_child(lamp)

	chunk.add_child(loot)
	var pos: Vector3 = job.get("pos", Vector3.ZERO)
	loot.position = pos + Vector3(0, 0.9, 0)
	loot._base_y = loot.position.y
	loot.body_entered.connect(loot._on_body_entered)
	return loot

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * BOB_SPEED) * BOB_HEIGHT
	if _mesh != null:
		_mesh.rotation.y += SPIN_SPEED * delta

func _on_body_entered(body: Node3D) -> void:
	if _world == null or not is_instance_valid(_world):
		return
	var character := body as Character
	if character == null or character != _world.active_character():
		return
	lifted.emit()
	queue_free()
