## One reusable character scene for both sides — docs/architecture.md.
## Side comes from `team` (0 = player squad, 1 = enemies), not scene type.
## Controllers (player / follower / enemy) drive movement; this script owns
## hp, the shield layer, the 3-slot gear loadout, ability action slots, and
## death / downed-revive.
##
## Health model: shields absorb damage first and regenerate a few seconds
## after last taking fire; HP underneath never regenerates in-mission. Crew
## (team 0) don't die at 0 HP — they go DOWN, and revive when a living
## squadmate stands close for a few seconds. Enemies just die.
class_name Character
extends CharacterBody3D

signal character_died(character: Character)
signal character_downed(character: Character)
signal character_revived(character: Character)
signal ability_activated(character: Character, ability: Ability)
signal hp_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal weapon_changed(slot: int)
## Someone fired at this character (hit or miss) — controllers use it for
## return-fire alerts and threat pinning.
signal shot_at(attacker: Character)

const MAX_ACTION_SLOTS := 4

const SHIELD_REGEN_DELAY := 4.0  # seconds without taking damage
const SHIELD_REGEN_RATE := 18.0  # points/second once regen kicks in
const REVIVE_RADIUS := 2.5       # a living squadmate this close revives
const REVIVE_SECS := 3.0
const REVIVE_HP_FRAC := 0.4      # back up at 40% HP, shields empty

@export var team := 0
@export var display_name := "Merc"
@export var max_hp := 100.0
## Shield capacity — regenerating damage layer. 0 = no shields (enemies).
@export var max_shield := 0.0
## Locomotion clip set for the skin ("masc" / "femn").
@export var anim_set := "masc"

var hp: float
var shield: float
var downed := false

## Loadout: index 0 = primary, 1 = secondary, 2 = heavy/device. Slot keys 1-3.
var gear_slots: Array = [null, null, null]
var active_slot := 0
## Abilities registered by equipped gear (max 4) — HUD reads this.
var action_slots: Array = []
## ability → msec tick when it is ready again.
var _cooldown_until: Dictionary = {}

var _last_damage_ms := 0
var _revive_progress := 0.0
var _down_label: Label3D = null

func _ready() -> void:
	hp = max_hp
	shield = max_shield
	collision_layer = Layers.body_layer(team)
	add_to_group("team_%d" % team)

func is_alive() -> bool:
	return hp > 0.0

func _process(delta: float) -> void:
	if downed:
		_tick_revive(delta)
		return
	if not is_alive() or max_shield <= 0.0 or shield >= max_shield:
		return
	if Time.get_ticks_msec() - _last_damage_ms < int(SHIELD_REGEN_DELAY * 1000.0):
		return
	shield = minf(max_shield, shield + SHIELD_REGEN_RATE * delta)
	shield_changed.emit(shield, max_shield)

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
	_last_damage_ms = Time.get_ticks_msec()
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		shield_changed.emit(shield, max_shield)
	if amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
	else:
		CharacterAnimator.oneshot(self, "hit", 1.4, 0.5)

func _die() -> void:
	CharacterAnimator.oneshot(self, "death")
	# Dropped bodies stop blocking shots, clicks, and movement.
	collision_layer = 0
	set_physics_process(false)
	if team == 0:
		_enter_downed()
	else:
		character_died.emit(self)

# ── Downed / revive (crew only) ──────────────────────────────────────────────

func _enter_downed() -> void:
	downed = true
	_revive_progress = 0.0
	_down_label = Label3D.new()
	_down_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_down_label.font_size = 52
	_down_label.pixel_size = 0.004
	_down_label.outline_size = 10
	_down_label.no_depth_test = true
	_down_label.modulate = Color(1.0, 0.35, 0.3)
	_down_label.text = "DOWN"
	add_child(_down_label)
	_down_label.position = Vector3(0, 2.0, 0)
	character_downed.emit(self)

func _tick_revive(delta: float) -> void:
	var reviver_near := false
	for node in get_tree().get_nodes_in_group("team_%d" % team):
		var mate := node as Character
		if mate == null or mate == self or not mate.is_alive():
			continue
		if global_position.distance_to(mate.global_position) <= REVIVE_RADIUS:
			reviver_near = true
			break
	if not reviver_near:
		if _down_label != null:
			_down_label.text = "DOWN"
		return
	_revive_progress += delta
	if _down_label != null:
		_down_label.text = "REVIVING %d%%" % int(100.0 * _revive_progress / REVIVE_SECS)
		_down_label.modulate = Color(0.4, 1.0, 0.55)
	if _revive_progress >= REVIVE_SECS:
		_revive()

func _revive() -> void:
	downed = false
	hp = max_hp * REVIVE_HP_FRAC
	shield = 0.0
	_last_damage_ms = Time.get_ticks_msec()  # shields wait the full delay
	collision_layer = Layers.body_layer(team)
	set_physics_process(true)
	if _down_label != null:
		_down_label.queue_free()
		_down_label = null
	CharacterAnimator.revive(self)
	hp_changed.emit(hp, max_hp)
	shield_changed.emit(shield, max_shield)
	character_revived.emit(self)

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
