## The hideout's training screen — spend the crew's earned perk picks.
## Opened by the map console when picks are owed (the map is one key away
## on M regardless). One pick per member per crew level; options come from
## Perks.CATALOG minus what that member already took.
class_name TrainingPanel
extends CanvasLayer

static var _open_instance: TrainingPanel = null

var _world: GameWorld

static func toggle(parent: Node, world: GameWorld) -> void:
	if _open_instance != null and is_instance_valid(_open_instance):
		_open_instance.queue_free()
		_open_instance = null
		return
	var panel := TrainingPanel.new()
	panel.layer = 55
	panel._world = world
	parent.add_child(panel)
	panel._build()
	_open_instance = panel

func _build() -> void:
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = UITheme.theme
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 0)
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "TRAINING — CREW LEVEL %d" % GameState.crew_level
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.C_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	for key in Skins.crew_names():
		var owed := GameState.picks_owed(key)
		var header := Label.new()
		header.text = "%s%s" % [String(key).capitalize(),
			"  ·  %d pick%s" % [owed, "" if owed == 1 else "s"] if owed > 0 else "  ·  trained"]
		header.add_theme_font_size_override("font_size", 17)
		header.add_theme_color_override("font_color",
			UITheme.C_ACCENT if owed > 0 else UITheme.C_MUTED)
		vbox.add_child(header)
		if owed <= 0:
			continue
		for perk_id in Perks.options_for(key).slice(0, 3):
			var info: Dictionary = Perks.CATALOG[perk_id]
			var pick := Button.new()
			pick.text = "%s — %s" % [info["name"], info["blurb"]]
			pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var member_key := String(key)
			var chosen := String(perk_id)
			pick.pressed.connect(func():
				if GameState.take_perk(member_key, chosen):
					var body := _member_body(member_key)
					if body != null:
						Perks.apply(body, chosen)
					AudioManager.play_sfx("revive")
					_build())
			vbox.add_child(pick)
	var close := Button.new()
	close.text = "Done"
	close.pressed.connect(func():
		queue_free()
		_open_instance = null)
	vbox.add_child(close)

func _member_body(member_key: String) -> Character:
	for member in GameState.squad:
		var c := member as Character
		if c != null and is_instance_valid(c) \
				and c.display_name.to_lower() == member_key:
			return c
	return null
