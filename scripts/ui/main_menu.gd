## Boot menu — title, enter the district, quit. Deliberately spare; the
## hideout is the real front-of-house.
extends Control

func _ready() -> void:
	theme = UITheme.theme
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)
	var title := Label.new()
	title.text = "GUTSHOT"
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", UITheme.C_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var tagline := Label.new()
	tagline.text = "the Vantag District doesn't forgive"
	tagline.add_theme_color_override("font_color", UITheme.C_MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tagline)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)
	if SaveManager.has_save():
		var cont := Button.new()
		cont.text = "Continue"
		cont.pressed.connect(func():
			GameState.new_run()
			var site := GameState.load_game()
			SceneManager.start_world(site))
		vbox.add_child(cont)
	var enter := Button.new()
	enter.text = "New Run"
	enter.pressed.connect(func():
		GameState.new_run()
		GameState.crew_state = {}
		SceneManager.start_world("hideout"))
	vbox.add_child(enter)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit)
	# Neon flicker on the title — cheap life.
	var tween := create_tween().set_loops()
	tween.tween_property(title, "modulate:a", 0.85, 1.2)
	tween.tween_property(title, "modulate:a", 1.0, 0.15)
