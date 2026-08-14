## Per-site objective tracking for the seamless district. Enemies register
## under their site; a site's required enemies hitting zero fires
## site_cleared (respawn un-clears it via clear_site + re-register). The only
## global end state left is the squad wipe. Neutral-faction characters
## register with required=false — they join fights but never gate a site.
class_name ObjectiveManager
extends Node

signal objective_updated(squad_left: int, enemies_left: int)
signal site_cleared(site_id: String)
signal mission_failed

var _squad: Array = []
var _sites: Dictionary = {}  # site_id -> Array[Character] (required enemies)
var _failed := false

func register(character: Character, site_id := "", required := true) -> void:
	if character.team == 0:
		if not _squad.has(character):
			_squad.append(character)
			# Crew go DOWN instead of dying; all-downed is still a wipe
			# (nobody left standing to revive).
			character.character_downed.connect(_on_crew_down)
	elif required:
		var list: Array = _sites.get_or_add(site_id, [])
		if not list.has(character):
			list.append(character)
		if not character.character_died.is_connected(_on_enemy_died):
			character.character_died.connect(_on_enemy_died.bind(site_id))
	objective_updated.emit(_living(_squad), enemies_left())

## Respawn support: drop a site's roster so the fresh pack re-registers.
func clear_site(site_id: String) -> void:
	_sites[site_id] = []

func site_clear(site_id: String) -> bool:
	return _living(_sites.get(site_id, [])) == 0

func enemies_left() -> int:
	var total := 0
	for site_id in _sites:
		total += _living(_sites[site_id])
	return total

func _living(list: Array) -> int:
	var count := 0
	for c in list:
		if is_instance_valid(c) and (c as Character).is_alive():
			count += 1
	return count

func _on_enemy_died(_character: Character, site_id: String) -> void:
	objective_updated.emit(_living(_squad), enemies_left())
	if site_clear(site_id):
		site_cleared.emit(site_id)

func _on_crew_down(_character: Character) -> void:
	if _failed:
		return
	var squad_left := _living(_squad)
	objective_updated.emit(squad_left, enemies_left())
	if squad_left == 0:
		_failed = true
		mission_failed.emit()
		GameState.end_mission(false)
