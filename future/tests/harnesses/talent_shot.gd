## Screenshot of the crew tree at a mid-run level — run with:
##   xvfb-run -a godot res://future/tests/harnesses/talent_shot.tscn
extends Node

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = true
	GameState.start_site = "hideout"
	var world: GameWorld = load("res://scenes/district.tscn").instantiate()
	add_child(world)
	for i in 600:
		await get_tree().physics_frame
		if GameState.squad.size() == 4:
			break
	# A crew partway up the ladder: some ranks down, a milestone just opened.
	GameState.crew_level = 15
	GameState.talents = {"toughness": 3, "marksman": 2, "capacitor": 2,
		"quick_hands": 1, "hardened": 1, "smoke_screen": 1, "light_step": 1}
	DirAccess.make_dir_recursive_absolute("res://.screenshots")
	TrainingPanel.toggle(world, world)
	for i in 30:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.screenshots/talent_tree.png")
	print("TALENT_SHOT: DONE")
	get_tree().quit(0)
