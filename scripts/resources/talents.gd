## The crew tree — ONE shared trunk, one point pool, spent at the hideout.
##
## The design tension this resolves: four crew members × a tree each is four
## menus and thirty-odd decisions a run. So there is no "which member" axis
## at all. Nodes buff the whole crew by default, and the handful that carry
## crew IDENTITY are ROLE-TAGGED — "Point Man" trains the leader, "Field
## Surgeon" the medic — but they live in the same tree and cost from the same
## pool. You never pick a person; you pick a node.
##
## Depth comes from MILESTONE gating rather than breadth: a tier is sealed
## until the crew hits its level, and most tier-2+ nodes also want ranks in a
## specific earlier node. So the tree opens up over a long run instead of
## presenting everything at once.
##
## Ranks are how a big point budget (2/level, cap 50) stays readable: a
## handful of nodes that deepen, not a hundred that don't.
class_name Talents
extends RefCounted

## Crew level a tier unlocks at. These ARE the milestones — the moments a
## level-up hands you something genuinely new instead of another rank.
##
## Placed against where players ACTUALLY land (pacing_probe): ~level 4 after
## one session, 11 after ten, 18 after forty, 24 after eighty. The first cut
## gated tier 4 at 22 and tier 5 at 35, which made two of the five tiers
## decoration rather than content. The XP curve is deliberately steep and
## stays that way; the gates moved to meet it.
const TIER_LEVEL := {1: 1, 2: 4, 3: 8, 4: 14, 5: 22}

## role "" = the whole crew. Otherwise a Skins.CREW key: the node trains that
## member only, which is where individuality lives without a member menu.
## requires/req_ranks = the prerequisite node and how many ranks of it.
const CATALOG := {
	# ── Tier 1 — foundations, open from the start, deepen with ranks ──────
	"toughness": {
		"name": "Scar Tissue", "blurb": "+12 max HP", "tier": 1, "ranks": 5,
		"requires": "", "req_ranks": 0, "role": "",
	},
	"capacitor": {
		"name": "Capacitor Rig", "blurb": "+10 shield capacity", "tier": 1,
		"ranks": 5, "requires": "", "req_ranks": 0, "role": "",
	},
	"marksman": {
		"name": "Dead Eye", "blurb": "+5% weapon damage", "tier": 1, "ranks": 5,
		"requires": "", "req_ranks": 0, "role": "",
	},
	# ── Tier 2 — level 4; each wants a foundation under it ───────────────
	"quick_hands": {
		"name": "Quick Hands", "blurb": "-8% ability cooldowns", "tier": 2,
		"ranks": 3, "requires": "marksman", "req_ranks": 2, "role": "",
	},
	"hardened": {
		"name": "Hardened Plating", "blurb": "Shields regenerate 60% faster",
		"tier": 2, "ranks": 1, "requires": "capacitor", "req_ranks": 2, "role": "",
	},
	"light_step": {
		"name": "Light Step", "blurb": "+8% movement speed", "tier": 2,
		"ranks": 2, "requires": "", "req_ranks": 0, "role": "",
	},
	# ── The KIT line: every tier hands the crew a new VERB ────────────────
	"smoke_screen": {
		"name": "Smoke Screen", "blurb": "ABILITY — throw a blinding cloud (real cover, blinds them too)",
		"tier": 2, "ranks": 1, "requires": "quick_hands", "req_ranks": 1, "role": "",
	},
	"field_dressing": {
		"name": "Field Dressing", "blurb": "Revive at 60% HP instead of 40%",
		"tier": 2, "ranks": 1, "requires": "toughness", "req_ranks": 2, "role": "",
	},
	# ── Tier 3 — level 8; the first role nodes ───────────────────────────
	"steady_aim": {
		"name": "Steady Aim", "blurb": "+6% accuracy", "tier": 3, "ranks": 3,
		"requires": "quick_hands", "req_ranks": 1, "role": "",
	},
	"second_wind": {
		"name": "Second Wind", "blurb": "+25 max HP for everyone", "tier": 3,
		"ranks": 1, "requires": "field_dressing", "req_ranks": 1, "role": "",
	},
	"focus_fire": {
		"name": "Focus Fire", "blurb": "ABILITY — order the whole crew onto the target under your cursor",
		"tier": 3, "ranks": 1, "requires": "smoke_screen", "req_ranks": 1, "role": "",
	},
	"point_man": {
		"name": "Point Man", "blurb": "The LEADER gains +40 shield", "tier": 3,
		"ranks": 1, "requires": "hardened", "req_ranks": 1, "role": "leader",
	},
	"suppressor": {
		"name": "Suppressor", "blurb": "The GUNNER deals +20% damage", "tier": 3,
		"ranks": 1, "requires": "marksman", "req_ranks": 3, "role": "gunner",
	},
	# ── Tier 4 — level 14 ────────────────────────────────────────────────
	"field_surgeon": {
		"name": "Field Surgeon", "blurb": "The MEDIC is hard to put down: +60 HP, revives at 90%",
		"tier": 4, "ranks": 1, "requires": "second_wind", "req_ranks": 1,
		"role": "medic",
	},
	"overclock": {
		"name": "Overclock", "blurb": "The HACKER's cooldowns drop 40%", "tier": 4,
		"ranks": 1, "requires": "quick_hands", "req_ranks": 2, "role": "hacker",
	},
	"combat_stim": {
		"name": "Combat Stim", "blurb": "ABILITY — heal 45 and move faster for five seconds",
		"tier": 4, "ranks": 1, "requires": "focus_fire", "req_ranks": 1, "role": "",
	},
	"executioner": {
		"name": "Executioner", "blurb": "+15% weapon damage", "tier": 4, "ranks": 2,
		"requires": "suppressor", "req_ranks": 1, "role": "",
	},
	# ── Tier 5 — level 22; capstones ─────────────────────────────────────
	"crew_of_legend": {
		"name": "Crew of Legend", "blurb": "+50 HP and +50 shield, every member",
		"tier": 5, "ranks": 1, "requires": "second_wind", "req_ranks": 1, "role": "",
	},
	"emp_charge": {
		"name": "EMP Charge", "blurb": "ABILITY — strips shields in a radius and staggers machines",
		"tier": 5, "ranks": 1, "requires": "combat_stim", "req_ranks": 1, "role": "",
	},
	"demolitions": {
		"name": "Demolitions Training", "blurb": "The whole crew carries frag grenades",
		"tier": 5, "ranks": 1, "requires": "executioner", "req_ranks": 1, "role": "",
	},
}

const FRAG := preload("res://resources/abilities/frag_grenade.tres")
const SMOKE := preload("res://resources/abilities/smoke_screen.tres")
const FOCUS := preload("res://resources/abilities/focus_fire.tres")
const STIM := preload("res://resources/abilities/combat_stim.tres")
const EMP := preload("res://resources/abilities/emp_charge.tres")

## Ability nodes hand the crew a VERB rather than a number. They go into the
## same action_slots gear uses, so the kit bar, the cooldown display and the
## follower AI all pick them up with no special casing.
const GRANTS := {
	"smoke_screen": SMOKE, "focus_fire": FOCUS,
	"combat_stim": STIM, "emp_charge": EMP, "demolitions": FRAG,
}

static func node(id: String) -> Dictionary:
	return CATALOG.get(id, {})

static func ranks_in(id: String) -> int:
	return int(GameState.talents.get(id, 0))

static func tier_unlocked(tier: int) -> bool:
	return GameState.crew_level >= int(TIER_LEVEL.get(tier, 99))

## Why a node can't be bought right now — "" means it can. The panel shows
## this instead of a dead greyed button, so the tree teaches its own rules.
static func blocked_reason(id: String) -> String:
	var n := node(id)
	if n.is_empty():
		return "unknown"
	var tier := int(n["tier"])
	if not tier_unlocked(tier):
		return "crew level %d" % int(TIER_LEVEL.get(tier, 99))
	if ranks_in(id) >= int(n["ranks"]):
		return "maxed"
	var req := str(n["requires"])
	if req != "" and ranks_in(req) < int(n["req_ranks"]):
		return "needs %s %d" % [str(node(req).get("name", req)), int(n["req_ranks"])]
	if GameState.talent_points_owed() <= 0:
		return "no points"
	return ""

static func can_buy(id: String) -> bool:
	return blocked_reason(id) == ""

## Apply ONE rank of a talent to a live body. Spawn replays every purchased
## rank through here, and a purchase applies just the new one — so the two
## paths can never drift apart.
static func apply_rank(c: Character, member_key: String, id: String) -> void:
	var n := node(id)
	if n.is_empty():
		return
	var role := str(n.get("role", ""))
	if role != "" and role != member_key:
		return  # a role node trains one member; everyone else skips it
	if GRANTS.has(id):
		var ability: Ability = GRANTS[id]
		if not c.action_slots.has(ability) \
				and c.action_slots.size() < Character.MAX_ACTION_SLOTS:
			c.action_slots.append(ability)
		return
	match id:
		"toughness":
			c.max_hp += 12.0
			c.hp += 12.0
			c.hp_changed.emit(c.hp, c.max_hp)
		"capacitor":
			c.max_shield += 10.0
			c.shield += 10.0
			c.shield_changed.emit(c.shield, c.max_shield)
		"marksman":
			c.damage_mult *= 1.05
		"quick_hands":
			c.cooldown_mult *= 0.92
		"hardened":
			c.shield_regen_mult *= 1.6
		"field_dressing":
			c.revive_frac = maxf(c.revive_frac, 0.6)
		"steady_aim":
			c.accuracy_mult *= 1.06
		"second_wind":
			c.max_hp += 25.0
			c.hp += 25.0
			c.hp_changed.emit(c.hp, c.max_hp)
		"point_man":
			c.max_shield += 40.0
			c.shield += 40.0
			c.shield_changed.emit(c.shield, c.max_shield)
		"suppressor":
			c.damage_mult *= 1.2
		"field_surgeon":
			c.max_hp += 60.0
			c.hp += 60.0
			c.revive_frac = maxf(c.revive_frac, 0.9)
			c.hp_changed.emit(c.hp, c.max_hp)
		"overclock":
			c.cooldown_mult *= 0.6
		"executioner":
			c.damage_mult *= 1.15
		"crew_of_legend":
			c.max_hp += 50.0
			c.hp += 50.0
			c.max_shield += 50.0
			c.shield += 50.0
			c.hp_changed.emit(c.hp, c.max_hp)
			c.shield_changed.emit(c.shield, c.max_shield)
		"light_step":
			c.base_speed_mult *= 1.08

## Replay the whole tree onto a freshly spawned body.
static func apply_all(c: Character, member_key: String) -> void:
	for id in CATALOG:
		for r in range(ranks_in(str(id))):
			apply_rank(c, member_key, str(id))

## Nodes in display order: tier, then catalog order.
static func by_tier(tier: int) -> Array:
	var out: Array = []
	for id in CATALOG:
		if int(CATALOG[id]["tier"]) == tier:
			out.append(id)
	return out
