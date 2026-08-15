## Autoload singleton — session-level game state. M1 is a single skirmish, so
## this stays slim: the squad roster, mission outcome signals, and the debug
## flag harnesses use to keep test runs away from any future save system.
extends Node

signal squad_updated
signal mission_ended(victory: bool)
## Every round leaving a gun, hit or wild — the district's ears (turf rules,
## future noise systems) listen here rather than patching every fire path.
signal shot_fired(shooter: Character)
signal xp_changed(total: int)
signal crew_leveled(new_level: int)
## Job state moved: accepted, lifted, banked or abandoned. The HUD line and
## the board both just re-read GameState when this fires.
signal job_changed

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

## Which site the crew spawns at when the district boots — set by
## SceneManager.start_world (menu New Run / Continue).
var start_site := "hideout"

# ── Progression: one squad XP pool → one crew level → per-member perks ───────

const LEVEL_CAP := 10
## Per-level flat curves applied at spawn and on live level-ups.
const HP_PER_LEVEL := 6.0
const SHIELD_PER_LEVEL := 4.0

var xp := 0
var crew_level := 1
## member key ("leader"…) → Array of taken perk ids (Perks.CATALOG).
var perks := {}
## Sites whose first-clear milestone already paid this run.
var cleared_sites: Array = []

# ── Jobs: accept at the board, lift on site, bank at the hideout ─────────────

## Accepted contract id (Jobs.CATALOG), or "" when the crew is between jobs.
var active_job := ""
## True once the loot is on the crew — the run home is live and the owner
## faction is hunting. Carried by the SQUAD, not a body, so a downed carrier
## never strands the job.
var carrying := false
## Jobs banked this run; the board stops offering them.
var completed_jobs: Array = []

func accept_job(id: String) -> bool:
	if active_job != "" or not Jobs.exists(id) or completed_jobs.has(id):
		return false
	active_job = id
	carrying = false
	job_changed.emit()
	return true

## Walk away from a contract. The loot goes back where it was; a grudge
## already earned is NOT refunded (see Jobs.lasting_grudge).
func abandon_job() -> void:
	if active_job == "":
		return
	active_job = ""
	carrying = false
	job_changed.emit()

func lift_loot() -> void:
	if active_job == "" or carrying:
		return
	carrying = true
	job_changed.emit()

## Bank at the hideout: pays out and retires the contract. Returns the XP
## paid (0 when there was nothing to bank) so the caller can show it.
func bank_job() -> int:
	if active_job == "" or not carrying:
		return 0
	var paid := int(Jobs.job(active_job).get("xp", 0))
	if not completed_jobs.has(active_job):
		completed_jobs.append(active_job)
	active_job = ""
	carrying = false
	add_xp(paid)
	job_changed.emit()
	return paid

## XP needed to go from `level` to level+1 (front-loaded early dings).
func xp_to_next(level: int = crew_level) -> int:
	return 200 * level

## Bank XP into the squad pool; levels resolve immediately (stat curves), but
## perk PICKS are only spendable at the hideout console — become stronger by
## making it home.
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	xp_changed.emit(xp)
	while crew_level < LEVEL_CAP and xp >= threshold_for(crew_level + 1):
		crew_level += 1
		crew_leveled.emit(crew_level)

## Total XP required to HOLD `level` (HUD shows progress toward the next).
func threshold_for(level: int) -> int:
	var total := 0
	for l in range(1, level):
		total += xp_to_next(l)
	return total

## Unspent perk picks across the whole crew (HUD nudge + console gate).
func total_picks_owed() -> int:
	var total := 0
	for key in Skins.crew_names():
		total += picks_owed(key)
	return total

## Perk picks a member has earned but not spent (one pick per level past 1).
func picks_owed(member_key: String) -> int:
	return (crew_level - 1) - (perks.get(member_key, []) as Array).size()

func take_perk(member_key: String, perk_id: String) -> bool:
	if picks_owed(member_key) <= 0 or not Perks.CATALOG.has(perk_id):
		return false
	var taken: Array = perks.get_or_add(member_key, [])
	if taken.has(perk_id):
		return false
	taken.append(perk_id)
	return true

## Menu entry point: this is a real run — saves may write. Progression
## resets here; Continue restores it right after via load_game.
func new_run() -> void:
	run_active = true
	debug_session = false
	xp = 0
	crew_level = 1
	perks = {}
	cleared_sites = []
	active_job = ""
	carrying = false
	completed_jobs = []

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
	return SaveManager.save_game(slot, {
		"site": site_id,
		"crew_state": crew_state,
		"xp": xp,
		"crew_level": crew_level,
		"perks": perks,
		"cleared_sites": cleared_sites,
		"active_job": active_job,
		"carrying": carrying,
		"completed_jobs": completed_jobs,
	})

## Restore a run: seeds crew_state + progression and reports the site to
## travel to. Empty string = no usable save. Version-1 saves simply lack the
## progression keys — defaults make them a fresh level-1 crew.
func load_game(slot: int = 0) -> String:
	var data := SaveManager.load_game(slot)
	if data.is_empty() or not data.has("site"):
		return ""
	crew_state = data.get("crew_state", {})
	xp = int(data.get("xp", 0))
	crew_level = int(data.get("crew_level", 1))
	perks = data.get("perks", {})
	cleared_sites = data.get("cleared_sites", [])
	active_job = str(data.get("active_job", ""))
	carrying = bool(data.get("carrying", false))
	completed_jobs = data.get("completed_jobs", [])
	job_changed.emit()
	return str(data["site"])
