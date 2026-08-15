## Retrieval contracts — the reason to leave the hideout.
##
## A job is one sentence: walk into somebody else's building, take their
## thing, and get it home. Every beat of that runs on systems the district
## already has —
##
##   the thing lives in an add_room interior, so the door is the only way in
##   for bullets, sight and pathfinding alike;
##   lifting it PROVOKES the owner, so their packs turn hostile and the
##   pursuit AI breaks their spawn leash to chase the carrier across sites;
##   and the hideout is the only place that banks it — which is also the
##   only place that heals.
##
## So the run home IS the job, and the fight on the way out is the point.
## Nothing here needs new AI; it needs a reason.
##
## Payment is worth several kills on purpose. A job has to beat farming a
## respawning pack, or the district goes back to being a shooting gallery.
class_name Jobs

## Every entry carries a `type`. v1 ships RETRIEVAL only — the runtime in
## GameWorld branches on it — but hit / sabotage / escort contracts are meant
## to land in this same catalog rather than a parallel system (docs/tasks.md).
##
## Loot positions are room CENTRES (see each site's add_room call) — dead
## centre is safely inside whatever the room's yaw is, which the corner of a
## rotated room is not.
const CATALOG := {
	"ledger": {
		"type": "retrieval",
		"name": "The Chop Shop Book",
		"blurb": "Every debt on this street is written in one ledger. Lift it and the gangs lose their grip on the block.",
		"site": "skirmish",
		"where": "the chop shop",
		"owner": Factions.GANGS,
		"loot": "LEDGER",
		"pos": Vector3(-16.0, 0.0, -20.0),
		"xp": 150,
	},
	"manifest": {
		"type": "retrieval",
		"name": "Depot 9 Manifest",
		"blurb": "The foreman's office keeps the freight manifest. It says what really moves through Depot 9, and for whom.",
		"site": "depot",
		"where": "the foreman's office",
		"owner": Factions.GANGS,
		"loot": "MANIFEST",
		"pos": Vector3(18.0, 0.0, 16.0),
		"xp": 180,
	},
	"blade": {
		"type": "retrieval",
		"name": "The Swordsmith's Blade",
		"blurb": "A finished katana rests in the Little Japan forge. The clan will never forgive this one — and the hideout's rest will not wash it off.",
		"site": "littlejapan",
		"where": "the swordsmith's forge",
		"owner": Factions.CLAN,
		"loot": "KATANA",
		"pos": Vector3(-20.0, 0.0, 6.0),
		"xp": 240,
	},
}

static func job(id: String) -> Dictionary:
	return CATALOG.get(id, {})

static func exists(id: String) -> bool:
	return CATALOG.has(id)

## Board listing: everything not already banked this run.
static func available() -> Array:
	var out: Array = []
	for id in CATALOG:
		if not GameState.completed_jobs.has(id):
			out.append(id)
	return out

static func owner_of(id: String) -> int:
	return int(job(id).get("owner", Factions.GANGS))

## The clan takes it personally: lifting their blade is an HONOR grudge, and
## Factions never forgives those on rest. Everyone else stays angry only
## until the crew makes it home and catches their breath.
static func lasting_grudge(id: String) -> bool:
	return owner_of(id) == Factions.CLAN
