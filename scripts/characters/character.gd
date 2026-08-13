## One reusable character scene for both sides — docs/architecture.md.
## Side comes from `team` (0 = player squad, 1 = enemies), not scene type.
## Controllers (player / follower / enemy) drive movement; this script owns
## hp, the 3-slot gear loadout, ability action slots, and death.
class_name Character
extends CharacterBody3D

signal character_died(character: Character)
signal ability_activated(character: Character, ability: Ability)
signal hp_changed(current: float, maximum: float)
signal weapon_changed(slot: int)
## Someone fired at this character (hit or miss) — controllers use it for
## return-fire alerts and threat pinning.
signal shot_at(attacker: Character)

const MAX_ACTION_SLOTS := 4

@export var team := 0
@export var display_name := "Merc"
@export var max_hp := 100.0
## Locomotion clip set for the skin ("masc" / "femn").
@export var anim_set := "masc"

var hp: float
## Post-v1 stub — always 0 for now; HUD renders the (empty) segment.
var shield := 0.0

## Loadout: index 0 = primary, 1 = secondary, 2 = heavy/device. Slot keys 1-3.
var gear_slots: Array = [null, null, null]
var active_slot := 0
## Abilities registered by equipped gear (max 4) — HUD reads this.
var action_slots: Array = []
## ability → msec tick when it is ready again.
var _cooldown_until: Dictionary = {}

func _ready() -> void:
	hp = max_hp
	collision_layer = Layers.body_layer(team)
	add_to_group("team_%d" % team)

func is_alive() -> bool:
	return hp > 0.0

func active_gear() -> GearItem:
	return gear_slots[active_slot]

func equip(gear: GearItem, slot: int = -1) -> void:
	if slot < 0:
		slot = gear.slot_type
	gear_slots[slot] = gear
	for ability in gear.abilities:
		if action_slots.size() < MAX_ACTION_SLOTS and not action_slots.has(ability):
			action_slots.append(ability)
	if slot == active_slot:
		weapon_changed.emit(active_slot)

func select_slot(slot: int) -> void:
	if slot == active_slot or slot < 0 or slot >= gear_slots.size() or gear_slots[slot] == null:
		return
	active_slot = slot
	weapon_changed.emit(slot)

## Cast `ability` at a world point, honoring its cooldown.
func activate_ability(ability: Ability, target_point: Vector3) -> bool:
	if not is_alive() or not action_slots.has(ability):
		return false
	if Time.get_ticks_msec() < int(_cooldown_until.get(ability, 0)):
		return false
	if not ability.activate(self, target_point):
		return false
	_cooldown_until[ability] = Time.get_ticks_msec() + int(ability.cooldown * 1000.0)
	ability_activated.emit(self, ability)
	return true

## Seconds until `ability` is ready (0 = ready now). HUD cooldown fill.
func cooldown_remaining(ability: Ability) -> float:
	return maxf(0.0, (int(_cooldown_until.get(ability, 0)) - Time.get_ticks_msec()) / 1000.0)

func notify_shot_at(attacker: Character) -> void:
	if is_alive():
		shot_at.emit(attacker)

func receive_damage(amount: float, _attacker: Node = null) -> void:
	if not is_alive():
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
	else:
		CharacterAnimator.oneshot(self, "hit", 1.4, 0.5)

func _die() -> void:
	CharacterAnimator.oneshot(self, "death")
	# Dead bodies stop blocking shots, clicks, and movement.
	collision_layer = 0
	set_physics_process(false)
	character_died.emit(self)

## Instance a Synty skin under the "Skin" child-node contract and attach the
## runtime animator. Idempotent per body.
func setup_skin(skin_path: String) -> void:
	if get_node_or_null("Skin") != null:
		return
	var scene = load(skin_path)
	if scene == null:
		push_warning("Missing skin (run fetch_assets.sh?): " + skin_path)
		return
	var skin: Node = scene.instantiate()
	skin.name = "Skin"
	add_child(skin)
	CharacterAnimator.attach(skin, self, anim_set)

## World-space positions cover raycasts test — head, chest, pelvis, shoulders.
func cover_points() -> Array:
	var pts := []
	for marker in get_node("CoverPoints").get_children():
		pts.append((marker as Node3D).global_position)
	return pts

func muzzle_position() -> Vector3:
	return ($Muzzle as Node3D).global_position
