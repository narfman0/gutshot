## Mission win/lose — docs/architecture.md signal contract. Subscribes every
## character's death; all enemies down → mission_complete, squad wiped →
## mission_failed. HUD listens to objective_updated for the remaining counts.
class_name ObjectiveManager
extends Node

signal objective_updated(squad_left: int, enemies_left: int)
signal mission_complete
signal mission_failed

var _squad: Array = []
var _enemies: Array = []
var _over := false

func register(character: Character) -> void:
	if character.team == 0:
		_squad.append(character)
		# Crew go DOWN instead of dying; all-downed is still a wipe (nobody
		# left standing to revive).
		character.character_downed.connect(_on_character_out)
	else:
		_enemies.append(character)
		character.character_died.connect(_on_character_out)
	objective_updated.emit(_living(_squad), _living(_enemies))

func _living(list: Array) -> int:
	var count := 0
	for c in list:
		if is_instance_valid(c) and (c as Character).is_alive():
			count += 1
	return count

func _on_character_out(_character: Character) -> void:
	if _over:
		return
	var squad_left := _living(_squad)
	var enemies_left := _living(_enemies)
	objective_updated.emit(squad_left, enemies_left)
	if enemies_left == 0:
		_over = true
		mission_complete.emit()
		GameState.end_mission(true)
	elif squad_left == 0:
		_over = true
		mission_failed.emit()
		GameState.end_mission(false)
