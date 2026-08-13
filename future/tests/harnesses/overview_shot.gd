## Visual gallery — run with:
##   xvfb-run -a godot res://future/tests/harnesses/overview_shot.tscn
## Boots the skirmish, lets the fight brew for a few seconds, and screenshots
## to .screenshots/ for eyeballing framing, skins, and cover play.
extends Node

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = false
	# SHOT_LEVEL=depot xvfb-run -a godot res://future/tests/harnesses/overview_shot.tscn
	var level := OS.get_environment("SHOT_LEVEL")
	if level == "":
		level = "skirmish"
	var world: GameWorld = load("res://scenes/levels/%s.tscn" % level).instantiate()
	add_child(world)
	for i in 10:
		await get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute("res://.screenshots")
	await _shot(level + "_t0.png")
	# Drag the crew toward the middle so the AI wakes up, then let it play.
	for member in GameState.squad:
		(member as Character).global_position += Vector3(0, 0, -8)
	await get_tree().create_timer(4.0).timeout
	await _shot(level + "_t4.png")
	await get_tree().create_timer(4.0).timeout
	await _shot(level + "_t8.png")
	print("OVERVIEW_SHOT: DONE")
	get_tree().quit(0)

func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.screenshots/" + file_name)
	print("saved ", file_name)
	for team in [0, 1]:
		for c in get_tree().get_nodes_in_group("team_%d" % team):
			var ch := c as Character
			print("  t%d %-10s pos=%s hp=%.0f" % [team, ch.display_name, ch.global_position, ch.hp])
