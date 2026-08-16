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

## Four was enough when abilities came only from gear. The crew tree grants
## them too now, so the kit has room to grow across a run.
const MAX_ACTION_SLOTS := 6

## One gravity for every mover. Deliberately heavier than Earth (games run
## 2-3× or drops feel like moon-walking); tuned against the catwalk height.
const GRAVITY := 24.0
## Landing read threshold — falls slower than this land silently.
const HARD_LANDING_VY := -6.0

## Gameplay-driven proportion squash: everything standing (characters, cover
## props) is compressed vertically so bodies and crates take less screen
## height at the iso pitch — deliberately, unrealistically squat. 1.0 = off.
const VERTICAL_SQUASH := 0.8

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

## Progression hooks (the crew tree multiplies these; see Talents.apply_rank).
var damage_mult := 1.0
var cooldown_mult := 1.0
var revive_frac := REVIVE_HP_FRAC
var shield_regen_mult := 1.0
var accuracy_mult := 1.0
## Permanent movement multiplier from the crew tree (Light Step).
var base_speed_mult := 1.0
## Combat Stim window: movement runs faster until this tick.
var stim_until_ms := 0
var stim_speed_mult := 1.0
## EMP stagger: machines do nothing at all until this tick. Their lack of
## morale is the point of them, so this is what "breaking" looks like.
var stagger_until_ms := 0

## Speed multiplier from live effects — one place so every mover agrees.
func effect_speed_mult() -> float:
	var m := base_speed_mult
	if Time.get_ticks_msec() < stim_until_ms:
		m *= stim_speed_mult
	return m

func is_staggered() -> bool:
	return Time.get_ticks_msec() < stagger_until_ms
## Who last hurt this character — kill credit for the squad XP pool.
var last_attacker: Character = null

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
	add_to_group("characters")
	weapon_changed.connect(func(_slot): _refresh_held_weapon())
	_apply_squash()

## Compress the body's vertical metrics to match the squashed visuals: the
## collision capsule, the muzzle, and the cover sample points. The skin gets
## its scale in setup_skin; cover props get theirs in GameWorld.
func _apply_squash() -> void:
	if is_equal_approx(VERTICAL_SQUASH, 1.0):
		return
	var col := $CollisionShape3D as CollisionShape3D
	# The shape resource is shared by every instance — duplicate before sizing.
	var capsule := (col.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	capsule.height *= VERTICAL_SQUASH
	col.shape = capsule
	col.position.y *= VERTICAL_SQUASH
	($Muzzle as Node3D).position.y *= VERTICAL_SQUASH
	for marker in get_node("CoverPoints").get_children():
		(marker as Node3D).position.y *= VERTICAL_SQUASH

func is_alive() -> bool:
	return hp > 0.0

var _airborne := false
var _peak_fall_vy := 0.0

func _process(delta: float) -> void:
	if downed:
		_tick_revive(delta)
		return
	if not is_alive():
		return
	_tick_landing()
	_unstick_from_prop_tops()
	if max_shield <= 0.0 or shield >= max_shield:
		return
	if Time.get_ticks_msec() - _last_damage_ms < int(SHIELD_REGEN_DELAY * 1000.0):
		return
	shield = minf(max_shield, shield + SHIELD_REGEN_RATE * shield_regen_mult * delta)
	shield_changed.emit(shield, max_shield)

## Landing read: falls off the catwalk get a thump and a dust kick so the
## drop feels like contact, not teleportation.
func _tick_landing() -> void:
	if not is_on_floor():
		_airborne = true
		_peak_fall_vy = minf(_peak_fall_vy, velocity.y)
		return
	if _airborne:
		if _peak_fall_vy < HARD_LANDING_VY:
			AudioManager.play_sfx("land", -4.0)
			Juice.impact_burst(get_tree().current_scene,
				global_position, Color(0.5, 0.48, 0.42))
		_airborne = false
		_peak_fall_vy = 0.0

## Crowded pop-out shuffles can depenetrate a capsule UP onto a cover prop,
## leaving a character standing on a vending machine. Characters can't climb,
## so anyone well above the walkable plane gets snapped back to the nearest
## navmesh point. Levels are flat in M1; revisit for multi-floor.
const _PROP_TOP_Y := 0.9

func _unstick_from_prop_tops() -> void:
	# Only when STANDING somewhere elevated — a body mid-fall (dropping off
	# the catwalk) must fall under gravity, not teleport to the floor.
	if global_position.y <= _PROP_TOP_Y or not is_on_floor():
		return
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_regions(map).is_empty():
		return  # no navmesh (bare harness scene) — nothing sane to snap to
	var ground := NavigationServer3D.map_get_closest_point(map, global_position)
	var drop := global_position.y - ground.y
	# Prop-top scale only: a half-metre to ~3 m snap is a vending machine;
	# more than that means the navmesh under our FEET is missing (mid-rebake
	# region gap, upper floors) — never yank someone off a deck for that.
	if drop > 0.5 and drop < 3.0:
		global_position = ground + Vector3(0, 0.1, 0)
		velocity = Vector3.ZERO

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
	AudioManager.play_sfx("switch")
	weapon_changed.emit(slot)

## Cast `ability` at a world point, honoring its cooldown.
func activate_ability(ability: Ability, target_point: Vector3) -> bool:
	if not is_alive() or not action_slots.has(ability):
		return false
	if Time.get_ticks_msec() < int(_cooldown_until.get(ability, 0)):
		return false
	if not ability.activate(self, target_point):
		return false
	_cooldown_until[ability] = Time.get_ticks_msec() \
		+ int(ability.cooldown * cooldown_mult * 1000.0)
	ability_activated.emit(self, ability)
	return true

## Seconds until `ability` is ready (0 = ready now). HUD cooldown fill.
func cooldown_remaining(ability: Ability) -> float:
	return maxf(0.0, (int(_cooldown_until.get(ability, 0)) - Time.get_ticks_msec()) / 1000.0)

func receive_heal(amount: float) -> void:
	if not is_alive() or downed:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)

## Shield top-up from a mender beam — the corp support unit's whole job.
func receive_shield_charge(amount: float) -> void:
	if not is_alive() or downed or max_shield <= 0.0:
		return
	shield = minf(max_shield, shield + amount)
	shield_changed.emit(shield, max_shield)

func notify_shot_at(attacker: Character) -> void:
	if is_alive():
		shot_at.emit(attacker)

func receive_damage(amount: float, attacker: Node = null) -> void:
	if not is_alive():
		return
	_last_damage_ms = Time.get_ticks_msec()
	# Taking damage reveals the source — grenades included, not just gunfire —
	# and damage between non-hostile factions IS a provocation (shoot the
	# machines and the machines are in the fight).
	if attacker is Character:
		last_attacker = attacker
		Factions.note_attack(team, (attacker as Character).team)
		shot_at.emit(attacker)
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		shield_changed.emit(shield, max_shield)
		AudioManager.play_sfx_at("shield_hit", global_position)
	if amount <= 0.0:
		return
	# Machines ring; people don't. Same cue name pattern, different material.
	AudioManager.play_sfx_at(
		"impact_metal" if team == Factions.ASSEMBLY else "impact", global_position)
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
	AudioManager.play_sfx("down")
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
	hp = max_hp * revive_frac
	shield = 0.0
	_last_damage_ms = Time.get_ticks_msec()  # shields wait the full delay
	collision_layer = Layers.body_layer(team)
	set_physics_process(true)
	if _down_label != null:
		_down_label.queue_free()
		_down_label = null
	CharacterAnimator.revive(self)
	AudioManager.play_sfx("revive")
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
	if skin is Node3D:
		(skin as Node3D).scale.y *= VERTICAL_SQUASH
	CharacterAnimator.attach(skin, self, anim_set)
	_refresh_held_weapon()

## Put the active gear's mesh in the right hand via a BoneAttachment3D.
## Rebuilt on every weapon switch; no-op until the skin exists.
func _refresh_held_weapon() -> void:
	var skin := get_node_or_null("Skin")
	if skin == null:
		return
	var skels: Array = skin.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel: Skeleton3D = skels[0]
	var old := skel.get_node_or_null("HeldWeapon")
	if old != null:
		old.queue_free()
	var gear := active_gear()
	if gear == null or gear.mesh_path == "":
		return
	var scene = load(gear.mesh_path)
	if scene == null:
		return
	var attach := BoneAttachment3D.new()
	attach.name = "HeldWeapon"
	skel.add_child(attach)
	attach.bone_name = "Hand_R"
	var mesh: Node3D = scene.instantiate()
	attach.add_child(mesh)
	# The skeleton sits under the skin glTF's cm→m corrective node (0.01) and
	# the weapon glTF carries its own corrective — parented to a bone, the
	# weapon renders at 1/10000 scale. Cancel the inherited shrink (this also
	# cancels the vertical squash, which suits a rigid prop).
	var inherited := skel.global_transform.basis.get_scale()
	mesh.scale = Vector3(1.0 / inherited.x, 1.0 / inherited.y, 1.0 / inherited.z)
	# Grip into the palm — orientation tuned by screenshot.
	mesh.rotation_degrees = Vector3(0, 90, -90)

## World-space positions cover raycasts test — head, chest, pelvis, shoulders.
func cover_points() -> Array:
	var pts := []
	for marker in get_node("CoverPoints").get_children():
		pts.append((marker as Node3D).global_position)
	return pts

func muzzle_position() -> Vector3:
	return ($Muzzle as Node3D).global_position
