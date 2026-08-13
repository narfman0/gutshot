## Autoload singleton — session-level game state. M1 is a single skirmish, so
## this stays slim: the squad roster, mission outcome signals, and the debug
## flag harnesses use to keep test runs away from any future save system.
extends Node

signal squad_updated
signal mission_ended(victory: bool)

## Characters in the player squad, in portrait order. Set by GameWorld.
var squad: Array = []

## Set by GameWorld when it spawns a fallback debug squad (scene run in
## isolation / headless harness) — persistence, once it exists, must check
## this and refuse to write.
var debug_session := false

func set_squad(characters: Array) -> void:
	squad = characters
	squad_updated.emit()

func living_squad() -> Array:
	return squad.filter(func(c): return is_instance_valid(c) and c.is_alive())

func end_mission(victory: bool) -> void:
	mission_ended.emit(victory)
