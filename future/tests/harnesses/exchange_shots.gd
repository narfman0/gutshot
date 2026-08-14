## Visual gallery for the Exchange's floor reveal — run with:
##   xvfb-run -a godot res://future/tests/harnesses/exchange_shots.tscn
## Screenshots each reveal state to .screenshots/: ground (galleries hidden),
## mid-climb (partial fade-in), gallery active, counting house active, and
## back on the ground.
extends Node

var _world: GameWorld
var _leader: Character

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	_world = load("res://scenes/levels/exchange.tscn").instantiate()
	add_child(_world)
	for i in 10:
		await get_tree().physics_frame
	_leader = GameState.squad[0]
	DirAccess.make_dir_recursive_absolute("res://.screenshots")
	await _shot("exchange_1_ground.png", 30)
	# Mid-climb on the west ramp: ~87% of the rise — the gallery should be
	# partially materialized, floor state still ground.
	_leader.global_position = Vector3(-26, 2.7, 15.8)
	await _shot("exchange_2_midclimb.png", 20)
	_leader.global_position = Vector3(-26, 3.05, -5)
	await _shot("exchange_3_gallery.png", 50)
	_leader.global_position = Vector3(0.5, 6.05, -25)
	await _shot("exchange_4_top.png", 50)
	_leader.global_position = Vector3(0, 0.1, 15)
	await _shot("exchange_5_return.png", 50)
	print("EXCHANGE_SHOTS: DONE")
	get_tree().quit(0)

func _shot(file_name: String, settle_frames: int) -> void:
	for i in settle_frames:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.screenshots/" + file_name)
	var fs := _world.get_node_or_null("FloorSystem") as FloorSystem
	if fs != null:
		print("saved %s  active_floor=%d opacity=%.2f/%.2f/%.2f" % [file_name,
			fs.active_floor, fs.opacity(0), fs.opacity(1), fs.opacity(2)])
