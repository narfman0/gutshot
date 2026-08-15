## Visual gallery for the seamless district — run with:
##   xvfb-run -a godot res://future/tests/harnesses/district_shots.tscn
## Screenshots the crew at each site and inside a connector corridor.
extends Node

var _world: GameWorld

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	GameState.start_site = "hideout"
	_world = load("res://scenes/district.tscn").instantiate()
	add_child(_world)
	for i in 600:
		await get_tree().physics_frame
		if GameState.squad.size() == 4:
			break
	# The gallery walks the crew through every fight in the district; they
	# are here to be PHOTOGRAPHED, not to survive on merit.
	for member in GameState.squad:
		var c := member as Character
		c.max_hp = 1000000.0
		c.hp = c.max_hp
	DirAccess.make_dir_recursive_absolute("res://.screenshots")
	await _shot("district_1_hideout.png", 30)
	_teleport(Vector3(-33.0, 0.1, 15.0))  # the alley
	await _shot("district_2_alley.png", 30)
	_teleport((_chunk("Street") as Node3D).global_position + Vector3(0, 0.1, 8))
	await _shot("district_3_street.png", 50)
	# Walk into the west pack's lap so the blade rusher charges for the camera.
	_teleport(Vector3(-9.0, 0.1, -8.0))
	await _shot("district_3b_rusher.png", 100)
	_teleport(Vector3(42.0, 0.1, 10.0))  # the arcade
	await _shot("district_4_arcade.png", 30)
	_teleport(_chunk("Exchange").to_global(Vector3(-26, 3.05, -5)))
	await _shot("district_5_exchange_gallery.png", 60)
	_teleport(Vector3(171.0, 0.1, 36.0))  # the freight tunnel
	await _shot("district_6_tunnel.png", 30)
	_teleport(_chunk("Depot").to_global(Vector3(0, 0.1, 12)))
	await _shot("district_7_depot.png", 60)
	_teleport(_chunk("Fab").to_global(Vector3(0, 0.1, 10)))
	await _shot("district_8_fab.png", 60)
	_teleport(_chunk("Tower").to_global(Vector3(0, 0.1, 14)))
	await _shot("district_9_tower_lobby.png", 60)
	_teleport(_chunk("Tower").to_global(Vector3(-22, 4.2, -2)))
	await _shot("district_10_tower_mezz.png", 60)
	# Break the seal and watch the Spawn pour onto the exec floor.
	for node in get_tree().get_nodes_in_group("breach_doors"):
		if (node as Node3D).global_position.y > 6.0:
			var seal := node as BreachDoor
			while is_instance_valid(seal) and seal.hp > 0.0:
				seal.receive_damage(80.0)
	_teleport(_chunk("Tower").to_global(Vector3(-2.5, 8.2, -13.0)))
	await _shot("district_11_horde.png", 420)
	# The other camera: over-the-shoulder with the reticle.
	_teleport((_chunk("Street") as Node3D).global_position + Vector3(0, 0.1, 8))
	_world.set_camera_mode(true)
	await _shot("district_12_ots.png", 60)
	# Same mode on the exchange gallery (railing overlook) and in the middle
	# of the tower's horde release — the two fights worth comparing.
	_teleport(_chunk("Exchange").to_global(Vector3(-26, 3.05, -5)))
	await _shot("district_13_ots_mezz.png", 90)
	_teleport(_chunk("Tower").to_global(Vector3(-2.5, 8.2, -14.0)))
	await _shot("district_14_ots_horde.png", 120)
	_world.set_camera_mode(false)
	print("DISTRICT_SHOTS: DONE")
	get_tree().quit(0)

func _chunk(site: String) -> SiteChunk:
	return _world.get_node("Level/" + site) as SiteChunk

## Move whoever the camera is actually following. (A downed leader hands
## control to the next crew member — teleporting the corpse would leave the
## camera somewhere else entirely.)
func _teleport(pos: Vector3) -> void:
	var active := _world.active_character()
	if active == null or not is_instance_valid(active):
		active = GameState.squad[0]
	active.global_position = pos

func _shot(file_name: String, settle_frames: int) -> void:
	for i in settle_frames:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.screenshots/" + file_name)
	print("saved %s  site=%s" % [file_name, _world.active_site_id()])
