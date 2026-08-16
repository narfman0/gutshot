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
## Payment is set by a rule, not by feel, and pacing_probe asserts the shape
## of it. Base by VERB — retrieval 300, hit 340, sabotage 360, escort 400,
## rising with how much can go wrong — plus 40 when the owner is a NEUTRAL
## faction, because a gang already wants the crew dead while the clan, the
## corp and the Assembly are enemies you have to MAKE. The clan blade takes
## another 20: that grudge is an honor grudge, and no rest ever forgives it.
##
## The floor those numbers have to clear: a job must out-pay simply clearing
## another site (~274 average), or the board is decoration and the best play
## is grinding the district. It averages ~357 against that 274.
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
		"xp": 300,
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
		"xp": 300,
	},
	# ── HIT — kill a named mark, carry the proof home ────────────────────
	"warlord": {
		"type": "hit",
		"name": "The Exchange Warlord",
		"blurb": "Someone has been organising the gangs out of the old trading floor. Take him off the board and bring back proof.",
		"site": "exchange",
		"where": "the trading floor",
		"owner": Factions.GANGS,
		"loot": "PROOF",
		"pos": Vector3(0.0, 0.1, 6.0),
		"mark_skin": "gangster",
		"mark_hp": 260.0,
		"mark_gear": "res://resources/gear/enemy_rifle.tres",
		"guards": 2,
		"xp": 340,
	},
	# ── SABOTAGE — wreck an installation, then get clear ─────────────────
	"assembler": {
		"type": "sabotage",
		"name": "Silence the Assembler",
		"blurb": "The Assembly's fabricator core keeps rebuilding what the district tears down. Put it out. They will not take it well.",
		"site": "fab",
		"where": "the fabricator sanctum",
		"owner": Factions.ASSEMBLY,
		"loot": "CORE SHARD",
		"pos": Vector3(0.0, 0.0, -14.0),
		"xp": 400,
	},
	# ── ESCORT — bring somebody OUT alive ────────────────────────────────
	"informant": {
		"type": "escort",
		"name": "The Vantag Informant",
		"blurb": "A clerk on the Vantag payroll wants out, and wants to talk. Walk into the lobby, walk him home. Security will object.",
		"site": "tower",
		"where": "the tower lobby",
		"owner": Factions.CORP,
		"loot": "INFORMANT",
		"pos": Vector3(10.0, 0.1, 6.0),
		"escort_skin": "suit",
		"xp": 440,
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
		"xp": 360,
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

static func type_of(id: String) -> String:
	return str(job(id).get("type", "retrieval"))

static func owner_of(id: String) -> int:
	return int(job(id).get("owner", Factions.GANGS))

## The clan takes it personally: lifting their blade is an HONOR grudge, and
## Factions never forgives those on rest. Everyone else stays angry only
## until the crew makes it home and catches their breath.
static func lasting_grudge(id: String) -> bool:
	return owner_of(id) == Factions.CLAN
