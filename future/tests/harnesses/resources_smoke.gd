## Headless resource-system smoke — run with:
##   godot --headless res://future/tests/harnesses/resources_smoke.tscn
## Loads every gear/ability .tres, equips a bare Character, asserts slot
## registration, slot switching, and cooldown gating.
extends Node

var _failures: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _ready() -> void:
	var smg: GearItem = load("res://resources/gear/smg.tres")
	var rifle: GearItem = load("res://resources/gear/rifle.tres")
	var pistol: GearItem = load("res://resources/gear/pistol.tres")
	var belt: GearItem = load("res://resources/gear/grenade_belt.tres")
	var frag: Ability = load("res://resources/abilities/frag_grenade.tres")
	_check(smg != null and smg.fire_mode == GearItem.FireMode.HITSCAN, "smg loads as HITSCAN GearItem")
	_check(rifle != null and rifle.slot_type == GearItem.SlotType.PRIMARY, "rifle is PRIMARY")
	_check(pistol != null and pistol.slot_type == GearItem.SlotType.SECONDARY, "pistol is SECONDARY")
	_check(belt != null and belt.fire_mode == GearItem.FireMode.THROWN, "belt is THROWN")
	_check(frag is FragGrenadeAbility, "frag_grenade is FragGrenadeAbility")
	_check(belt != null and belt.abilities.size() == 1 and belt.abilities[0] is FragGrenadeAbility,
		"belt exports the frag ability")

	var character: Character = load("res://scenes/characters/character.tscn").instantiate()
	add_child(character)
	character.equip(smg)
	character.equip(pistol)
	character.equip(belt)
	_check(character.gear_slots[0] == smg, "smg lands in slot 0")
	_check(character.gear_slots[1] == pistol, "pistol lands in slot 1")
	_check(character.gear_slots[2] == belt, "belt lands in slot 2")
	_check(character.action_slots.has(belt.abilities[0]), "frag registered into action_slots")
	_check(character.active_slot == 0, "primary active by default")
	character.select_slot(2)
	_check(character.active_slot == 2, "slot switch to heavy works")
	character.select_slot(9)
	_check(character.active_slot == 2, "out-of-range slot ignored")

	# Cooldown gating: first cast succeeds, immediate second cast is refused.
	var ability: Ability = belt.abilities[0]
	character.global_position = Vector3.ZERO
	var first := character.activate_ability(ability, Vector3(3, 0, 0))
	var second := character.activate_ability(ability, Vector3(3, 0, 0))
	_check(first, "first grenade cast succeeds")
	_check(not second, "second cast gated by cooldown")
	_check(character.cooldown_remaining(ability) > 0.0, "cooldown_remaining positive after cast")

	if _failures.is_empty():
		print("RESOURCES_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("RESOURCES_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
