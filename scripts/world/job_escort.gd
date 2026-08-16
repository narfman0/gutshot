## An escort job's package — a person who has to walk out alive.
##
## Sits on a spawned CIVIL body and drives it toward whoever the camera is
## following. Deliberately dumb: it navigates and it cowers, it does not
## fight, and it never tries to be clever about cover. An escort that
## outplays you is not tense, it is annoying.
##
## The contract only starts once the ACTIVE character walks up — same rule as
## the retrieval pickup, so a follower brushing past can't begin a job the
## player didn't choose.
class_name JobEscort
extends Node

signal contacted
signal died

const CONTACT_DIST := 3.0
const FOLLOW_SPEED := 7.6     # a shade under the crew, so they trail
const STOP_DIST := 3.2
const REJOIN_DIST := 22.0     # further than this and they sprint to catch up
const SPRINT_SPEED := 9.4

var world: GameWorld
var following := false

var _body: Character
var _brain: CombatBrain

static func attach(body: Character, world_ref: GameWorld) -> JobEscort:
	var escort := JobEscort.new()
	escort.name = "JobEscort"
	escort.world = world_ref
	body.add_child(escort)
	return escort

func _ready() -> void:
	_body = get_parent() as Character
	_brain = _body.get_node_or_null("CombatBrain") as CombatBrain
	_body.character_died.connect(func(_c): died.emit())
	# A nameplate, so the package is findable in a dressed site.
	var tag := Label3D.new()
	tag.text = "INFORMANT"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 30
	tag.pixel_size = 0.004
	tag.outline_size = 8
	tag.modulate = Color(0.5, 1.0, 0.7)
	tag.position.y = 2.3
	_body.add_child(tag)

func _physics_process(delta: float) -> void:
	if _body == null or not is_instance_valid(_body) or not _body.is_alive():
		return
	var active := world.active_character() if world != null else null
	if active == null or not is_instance_valid(active):
		return
	if not following:
		if _body.global_position.distance_to(active.global_position) <= CONTACT_DIST:
			following = true
			contacted.emit()
		return
	# Trail the crew. Falling too far behind (a corridor, a fight) switches to
	# a sprint so the package doesn't quietly strand itself across the district.
	var gap := _body.global_position.distance_to(active.global_position)
	if gap <= STOP_DIST or _brain == null:
		return
	var speed := SPRINT_SPEED if gap > REJOIN_DIST else FOLLOW_SPEED
	_brain.nav_to(active.global_position, delta, speed)
