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
	print("DISTRICT_SHOTS: DONE")
	get_tree().quit(0)

func _chunk(site: String) -> SiteChunk:
	return _world.get_node("Level/" + site) as SiteChunk

func _teleport(pos: Vector3) -> void:
	(GameState.squad[0] as Character).global_position = pos

func _shot(file_name: String, settle_frames: int) -> void:
	for i in settle_frames:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.screenshots/" + file_name)
	print("saved %s  site=%s" % [file_name, _world.active_site_id()])
