## Autoload singleton — session-level game state. M1 is a single skirmish, so
## this stays slim: the squad roster, mission outcome signals, and the debug
## flag harnesses use to keep test runs away from any future save system.
extends Node

signal squad_updated
signal mission_ended(victory: bool)

## Characters in the player squad, in portrait order. Set by GameWorld.
var squad: Array = []

## Crew condition carried between sites: crew key → {hp, shield, downed}.
## Captured on travel, applied on spawn, persisted by save_game. Empty =
## fresh crew at full strength.
var crew_state: Dictionary = {}

## Set by GameWorld when it spawns a fallback debug squad (scene run in
## isolation / headless harness) — saves refuse to write during these.
var debug_session := false

## True once the player enters through the menu. A level booting with an
## empty squad and NO active run is a debug/harness launch.
var run_active := false

## Menu entry point: this is a real run — saves may write.
func new_run() -> void:
	run_active = true
	debug_session = false

func set_squad(characters: Array) -> void:
	squad = characters
	squad_updated.emit()

func living_squad() -> Array:
	return squad.filter(func(c): return is_instance_valid(c) and c.is_alive())

func end_mission(victory: bool) -> void:
	mission_ended.emit(victory)

## Snapshot crew condition before a scene change frees the bodies. Downed
## crew get dragged along and arrive shaky.
func capture_crew() -> void:
	crew_state = {}
	for c in squad:
		if not is_instance_valid(c):
			continue
		var body := c as Character
		crew_state[body.display_name.to_lower()] = {
			"hp": maxf(body.hp, body.max_hp * 0.25) if body.downed else body.hp,
			"shield": 0.0 if body.downed else body.shield,
		}

## Autosave: current site + crew condition. Refuses during debug sessions —
## harness and standalone-scene runs must never touch a real slot.
func save_game(site_id: String, slot: int = 0) -> bool:
	if debug_session or site_id == "":
		return false
	return SaveManager.save_game(slot, {"site": site_id, "crew_state": crew_state})

## Restore a run: seeds crew_state and reports the site to travel to.
## Empty string = no usable save.
func load_game(slot: int = 0) -> String:
	var data := SaveManager.load_game(slot)
	if data.is_empty() or not data.has("site"):
		return ""
	crew_state = data.get("crew_state", {})
	return str(data["site"])
