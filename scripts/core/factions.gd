## Faction registry + hostility matrix. `Character.team` is a faction id.
##
## Base hostility is data; PROVOCATION is runtime state — the Assembly is
## neutral until someone damages a machine or overstays in their territory,
## then that faction is marked hostile both ways. Ordinary provocations are
## forgiven when the crew rests at the hideout (GameWorld._rest_crew calls
## reset_provocations). HONOR grudges are not: the clan never forgets.
class_name Factions

enum { CREW = 0, GANGS = 1, ASSEMBLY = 2, CORP = 3, HORDE = 4, CLAN = 5, CIVIL = 6 }

const NAMES := {
	CREW: "Crew", GANGS: "Gangs", ASSEMBLY: "The Assembly",
	CORP: "Vantag Security", HORDE: "The Spawn", CLAN: "The Clan",
	CIVIL: "Civilians",
}

## Overhead-bar / UI tint per faction.
const COLORS := {
	CREW: Color(0.20, 0.85, 0.45),
	GANGS: Color(0.90, 0.22, 0.25),
	ASSEMBLY: Color(1.0, 0.65, 0.2),
	CORP: Color(0.55, 0.75, 1.0),
	HORDE: Color(0.75, 0.3, 0.95),
	CLAN: Color(0.95, 0.25, 0.45),
	CIVIL: Color(0.85, 0.85, 0.80),
}

## Base wars: the gangs and the crew are at it from the first frame;
## corporate security exists to keep the gangs out; the clan polices its own
## streets and the gangs keep trying them. The Spawn is at war with
## EVERYTHING that breathes or computes — civilians included, which is
## rather the point of civilians.
const _BASE_HOSTILE := [
	[CREW, GANGS], [CORP, GANGS], [CLAN, GANGS],
	[HORDE, CREW], [HORDE, GANGS], [HORDE, ASSEMBLY], [HORDE, CORP],
	[HORDE, CLAN], [HORDE, CIVIL],
]

static var _provoked: Dictionary = {}
## Grudges that survive a rest — clan honor. Nothing in the game clears
## these: making peace with the clan is a campaign problem, not a nap.
static var _honor: Dictionary = {}

static func _key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]

## Forgive ordinary provocations (the hideout rest). Honor grudges stay.
static func reset_provocations() -> void:
	_provoked = {}

## Full wipe — new run / harness setup.
static func reset_all() -> void:
	_provoked = {}
	_honor = {}

static func hostile(a: int, b: int) -> bool:
	if a == b:
		return false
	for pair in _BASE_HOSTILE:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	var k := _key(a, b)
	return _provoked.has(k) or _honor.has(k)

## Mark two factions hostile until the crew next rests.
##
## This records the provocation even when the pair is ALREADY base-hostile.
## It used to early-out in that case as an optimisation, which quietly broke
## once engages_on_sight arrived: base-hostile NPC factions stand off until
## provoked, so if the provocation is never written down they can never
## escalate — a gang could shoot a ninja and the clan would never turn on
## them as a faction.
static func provoke(a: int, b: int) -> void:
	if a == b:
		return
	_provoked[_key(a, b)] = true

## A slight the offended party will not forget (clan honor).
static func provoke_lasting(a: int, b: int) -> void:
	if a == b:
		return
	_honor[_key(a, b)] = true

static func has_honor_grudge(a: int, b: int) -> bool:
	return _honor.has(_key(a, b))

## Damage between non-hostile factions IS a provocation (machines don't
## forgive friendly fire either) — and the clan escalates it to HONOR: draw
## blood on their street and they carry it for the rest of the run.
static func note_attack(victim_faction: int, attacker_faction: int) -> void:
	if victim_faction == CLAN or attacker_faction == CLAN:
		provoke_lasting(victim_faction, attacker_faction)
	else:
		provoke(victim_faction, attacker_faction)

## Will `a` START a fight with `b` unprompted, on sight?
##
## `hostile()` says who are ENEMIES. This says who PICKS the fight, and the
## two are not the same thing. Playtest 2026-08-15: walking in, several
## factions were already at war with each other, because base hostility made
## every gang/clan and gang/corp pair open fire the moment they saw one
## another. The district should be quiet and docile until something happens.
##
## So NPC factions who merely dislike each other now stand off. They still
## defend themselves — being shot routes through note_attack, which provokes
## — and once provoked they fight properly. Two exemptions: the CREW, because
## gangs jumping the player on sight IS the game, and the SPAWN, which is at
## war with everything that breathes or computes.
static func engages_on_sight(a: int, b: int) -> bool:
	if not hostile(a, b):
		return false
	if a == CREW or b == CREW or a == HORDE or b == HORDE:
		return true
	var k := _key(a, b)
	return _provoked.has(k) or _honor.has(k)

## Every living character hostile to `faction`, via the global "characters"
## group. Fine at squad scale; revisit if rosters grow past dozens.
static func hostiles_of(tree: SceneTree, faction: int) -> Array:
	var out: Array = []
	for node in tree.get_nodes_in_group("characters"):
		var c := node as Character
		if c != null and c.is_alive() and hostile(faction, c.team):
			out.append(c)
	return out

## Who `faction` will actually open up on unprompted — the list the AI's
## sight checks use, as opposed to the full enemies list.
static func sight_targets_of(tree: SceneTree, faction: int) -> Array:
	var out: Array = []
	for node in tree.get_nodes_in_group("characters"):
		var c := node as Character
		if c != null and c.is_alive() and engages_on_sight(faction, c.team):
			out.append(c)
	return out
