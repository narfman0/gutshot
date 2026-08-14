## Headless Exchange smoke — run with:
##   godot --headless res://future/tests/harnesses/exchange_smoke.tscn
## Asserts the multi-floor tech on the real level: one navmesh spans all
## three floors via the ramps, deck slabs block LOS through floors, the
## FloorSystem reveal state (hysteresis, climb reveal, hidden top floor,
## character visibility) tracks the active character, and the gallery watch
## actually engages the atrium below.
extends Node

var _failures: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	var world: GameWorld = load("res://scenes/levels/exchange.tscn").instantiate()
	add_child(world)
	await _settle(10)
	_check(GameState.squad.size() == 4, "crew spawned in the exchange")
	var map := world.get_world_3d().navigation_map

	# 1. One navmesh, three floors: paths climb to the gallery and on into
	#    the counting house (through the door gap).
	var to_gallery := NavigationServer3D.map_get_path(
		map, Vector3(0, 0.1, 20), Vector3(-26, 3.0, -5), true)
	_check(to_gallery.size() > 1 and to_gallery[to_gallery.size() - 1].y > 2.5,
		"gallery is navigable from the trading floor (end y %.1f)"
		% (to_gallery[to_gallery.size() - 1].y if to_gallery.size() > 0 else -1.0))
	var to_vault := NavigationServer3D.map_get_path(
		map, Vector3(0, 0.1, 20), Vector3(0, 6.0, -25), true)
	_check(to_vault.size() > 1 and to_vault[to_vault.size() - 1].y > 5.5,
		"counting house is navigable (end y %.1f)"
		% (to_vault[to_vault.size() - 1].y if to_vault.size() > 0 else -1.0))

	# 2. Elevation LOS: two floors of slab between the trading floor and the
	#    counting house — no line, no shot.
	var vault_body := (get_tree().get_nodes_in_group("pack_vault")[0] as EnemyController).body
	var leader := GameState.squad[0] as Character
	_check(Cover.exposure(leader.muzzle_position(), vault_body) <= Cover.FULL_COVER_MAX,
		"floors block LOS into the counting house")

	# 3. Reveal state on arrival: ground active, gallery + top hidden, and
	#    the counting-house crew hidden with their floor (gallery watch stays
	#    visible — one floor up is the overlook fight).
	var fs := world.get_node("FloorSystem") as FloorSystem
	_check(fs != null and fs.active_floor == 0, "arrive on the ground floor")
	_check(fs.opacity(0) == 1.0 and fs.opacity(1) == 0.0 and fs.opacity(2) == 0.0,
		"upper floors hidden on arrival (%.2f/%.2f/%.2f)"
		% [fs.opacity(0), fs.opacity(1), fs.opacity(2)])
	var gallery_body := (get_tree().get_nodes_in_group("pack_gallery")[0] as EnemyController).body
	var crew_line := false
	for member in GameState.squad:
		if (member as Character).is_alive() and Cover.exposure(
				(member as Character).muzzle_position(), gallery_body) > Cover.FULL_COVER_MAX:
			crew_line = true
			break
	_check(gallery_body.visible == crew_line,
		"overlook rule: gallery watch drawn iff crew has a line (drawn=%s line=%s)"
		% [gallery_body.visible, crew_line])
	_check(not vault_body.visible, "counting-house crew hidden two floors up")

	# 4. Hysteresis unit-check on the real object: partial climb reveals
	#    nothing, commit near the top, revert only well below the slab.
	fs._update_active_floor(2.6)
	_check(fs.active_floor == 0, "86%% of the climb does not commit the floor")
	fs._update_active_floor(2.75)
	_check(fs.active_floor == 1, "92%% of the climb commits the floor")
	fs._update_active_floor(1.9)
	_check(fs.active_floor == 1, "descending to 63%% keeps the floor (hysteresis)")
	fs._update_active_floor(1.7)
	_check(fs.active_floor == 0, "descending past 57%% reverts the floor")

	# 5. Live climb: stand the active character on the west gallery — the
	#    gallery fades in solid, the counting house stays dark.
	leader.global_position = Vector3(-26, 3.05, -5)
	await _settle(40)
	_check(fs.active_floor == 1, "gallery becomes the active floor (got %d)" % fs.active_floor)
	_check(fs.opacity(1) > 0.95, "gallery geometry revealed (%.2f)" % fs.opacity(1))
	_check(fs.opacity(2) == 0.0, "counting house still hidden from the gallery")

	# 6. Top floor: the counting house reveals, and its crew with it.
	leader.global_position = Vector3(0.5, 6.05, -25)
	await _settle(40)
	_check(fs.active_floor == 2, "counting house becomes the active floor (got %d)" % fs.active_floor)
	_check(fs.opacity(2) > 0.95, "counting house revealed (%.2f)" % fs.opacity(2))
	_check(vault_body.visible or not vault_body.is_alive(),
		"counting-house crew visible on their floor")

	# 7. Drop back to the trading floor: everything above dissolves again.
	leader.global_position = Vector3(0, 0.1, 15)
	await _settle(40)
	_check(fs.active_floor == 0, "back on the ground floor (got %d)" % fs.active_floor)
	_check(fs.opacity(1) < 0.05 and fs.opacity(2) < 0.05,
		"upper floors hidden again (%.2f/%.2f)" % [fs.opacity(1), fs.opacity(2)])

	# 8. The gallery watch works the atrium: a crew body in the open below a
	#    living watcher gets spotted (aggro reaches, deck edge doesn't block).
	var watcher: EnemyController = null
	for node in get_tree().get_nodes_in_group("pack_gallery"):
		if (node as EnemyController).body.is_alive():
			watcher = node
			break
	if watcher != null:
		leader.global_position = watcher.body.global_position + Vector3(12, 0, 4)
		leader.global_position.y = 0.1
		await _settle(30)
		_check(watcher.state != EnemyController.State.IDLE,
			"gallery watch engages the atrium below (state %d)" % watcher.state)
	else:
		_check(false, "no living gallery watcher left to test sight with")

	if _failures.is_empty():
		print("EXCHANGE_SMOKE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("EXCHANGE_SMOKE: %d FAILURES" % _failures.size())
		get_tree().quit(1)
