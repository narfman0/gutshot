## Player squad root — owns the crew Characters, wires their controllers, and
## routes active-character switching (Tab cycles, HUD portraits call
## set_active directly).
class_name Squad
extends Node3D

signal active_changed(index: int, character: Character)

## Wedge offsets for followers, assigned in join order.
const FORMATION := [
	Vector3(-1.6, 0, 1.4),
	Vector3(1.6, 0, 1.4),
	Vector3(0, 0, 2.6),
]

var members: Array = []
var active_index := 0

## Build controller stack on a crew Character and register it.
func add_member(character: Character) -> void:
	if character.get_parent() == null:
		add_child(character)
	var brain := CombatBrain.new()
	brain.name = "CombatBrain"
	character.add_child(brain)
	var player := PlayerController.new()
	player.name = "PlayerController"
	character.add_child(player)
	var follow := SquadFollow.new()
	follow.name = "SquadFollow"
	character.add_child(follow)
	members.append(character)
	character.character_died.connect(_on_member_died)
	_refresh_control()

func active_character() -> Character:
	if members.is_empty():
		return null
	return members[active_index]

func set_active(index: int) -> void:
	if index < 0 or index >= members.size() or not (members[index] as Character).is_alive():
		return
	active_index = index
	_refresh_control()
	active_changed.emit(active_index, members[active_index])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_character"):
		_cycle_active()

func _cycle_active() -> void:
	if members.is_empty():
		return
	for step in range(1, members.size() + 1):
		var idx := (active_index + step) % members.size()
		if (members[idx] as Character).is_alive():
			set_active(idx)
			return

func _refresh_control() -> void:
	var slot := 0
	for i in members.size():
		var character: Character = members[i]
		var player: PlayerController = character.get_node("PlayerController")
		var follow: SquadFollow = character.get_node("SquadFollow")
		var is_active: bool = i == active_index and character.is_alive()
		player.enabled = is_active
		follow.enabled = not is_active and character.is_alive()
		follow.leader = active_character()
		if not is_active:
			follow.formation_offset = FORMATION[slot % FORMATION.size()]
			slot += 1

## The player's view must never sit on a corpse — auto-switch on death.
func _on_member_died(character: Character) -> void:
	if character == active_character():
		_cycle_active()
	else:
		_refresh_control()

func living_members() -> Array:
	return members.filter(func(c): return (c as Character).is_alive())
