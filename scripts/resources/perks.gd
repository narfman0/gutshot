## The perk catalog — chunky, readable, per-member level-up picks (no +2%
## trickles; every perk changes something you can feel). Registry-style like
## Skins: ids are what saves store, apply() is idempotent per pick because
## GameState.take_perk refuses duplicates.
class_name Perks
extends RefCounted

const CATALOG := {
	"cap_rig": {"name": "Capacitor Rig", "blurb": "+25 shield capacity"},
	"scar_tissue": {"name": "Scar Tissue", "blurb": "+25 max HP"},
	"dead_eye": {"name": "Dead Eye", "blurb": "+15% weapon damage"},
	"quick_hands": {"name": "Quick Hands", "blurb": "Ability cooldowns -25%"},
	"stims": {"name": "Combat Stims", "blurb": "Revive at 60% HP instead of 40%"},
}

static func apply(c: Character, perk_id: String) -> void:
	match perk_id:
		"cap_rig":
			c.max_shield += 25.0
			c.shield += 25.0
			c.shield_changed.emit(c.shield, c.max_shield)
		"scar_tissue":
			c.max_hp += 25.0
			c.hp += 25.0
			c.hp_changed.emit(c.hp, c.max_hp)
		"dead_eye":
			c.damage_mult *= 1.15
		"quick_hands":
			c.cooldown_mult *= 0.75
		"stims":
			c.revive_frac = 0.6

## Perks `member_key` can still pick (owed picks are GameState's business).
static func options_for(member_key: String) -> Array:
	var taken: Array = GameState.perks.get(member_key, [])
	var out: Array = []
	for id in CATALOG:
		if not taken.has(id):
			out.append(id)
	return out
