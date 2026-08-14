## Faction registry + hostility matrix. `Character.team` is a faction id.
##
## Base hostility is data; PROVOCATION is runtime state — the Assembly is
## neutral until someone damages a machine or overstays in their territory,
## then that faction is marked hostile both ways for the rest of the site
## visit (GameWorld resets provocations on level load).
class_name Factions

enum { CREW = 0, GANGS = 1, ASSEMBLY = 2, CORP = 3, HORDE = 4 }

const NAMES := {CREW: "Crew", GANGS: "Gangs", ASSEMBLY: "The Assembly", CORP: "Vantag Security", HORDE: "The Spawn"}

## Overhead-bar / UI tint per faction.
const COLORS := {
	CREW: Color(0.20, 0.85, 0.45),
	GANGS: Color(0.90, 0.22, 0.25),
	ASSEMBLY: Color(1.0, 0.65, 0.2),
	CORP: Color(0.55, 0.75, 1.0),
	HORDE: Color(0.75, 0.3, 0.95),
}

## Base wars: the gangs and the crew are at it from the first frame, and
## corporate security exists to keep the gangs out. The crew and CORP start
## neutral — the lobby is public until you start something.
## The Spawn is at war with EVERYTHING that breathes or computes.
const _BASE_HOSTILE := [[CREW, GANGS], [CORP, GANGS],
	[HORDE, CREW], [HORDE, GANGS], [HORDE, ASSEMBLY], [HORDE, CORP]]

static var _provoked: Dictionary = {}

static func _key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]

static func reset_provocations() -> void:
	_provoked = {}

static func hostile(a: int, b: int) -> bool:
	if a == b:
		return false
	for pair in _BASE_HOSTILE:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return _provoked.has(_key(a, b))

## Mark two factions hostile for the rest of the site visit.
static func provoke(a: int, b: int) -> void:
	if a == b or hostile(a, b):
		return
	_provoked[_key(a, b)] = true

## Damage between non-hostile factions IS a provocation (machines don't
## forgive friendly fire either).
static func note_attack(victim_faction: int, attacker_faction: int) -> void:
	provoke(victim_faction, attacker_faction)

## Every living character hostile to `faction`, via the global "characters"
## group. Fine at squad scale; revisit if rosters grow past dozens.
static func hostiles_of(tree: SceneTree, faction: int) -> Array:
	var out: Array = []
	for node in tree.get_nodes_in_group("characters"):
		var c := node as Character
		if c != null and c.is_alive() and hostile(faction, c.team):
			out.append(c)
	return out
