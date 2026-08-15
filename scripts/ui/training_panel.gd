## The hideout's training screen — the crew tree, one shared trunk.
##
## Opened by the console while points are owed (the job board takes over once
## they're spent; the district map is on M regardless). Tiers are drawn as
## rows and stay VISIBLE while locked, with the crew level that opens them,
## so the tree advertises what the next milestone is worth.
##
## There is no member picker: nodes buff the whole crew, and the role-tagged
## ones say which member they train right in the blurb.
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

func _close() -> void:
	queue_free()
	_open_instance = null

func _build() -> void:
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	# Five tiers of nodes is taller than a screen, so the panel is a fixed
	# inset frame with the tree SCROLLING inside it. Anchored rather than
	# centre-sized, so it fits at any resolution instead of running off the
	# bottom the moment a tier is added.
	var panel := PanelContainer.new()
	panel.theme = UITheme.theme
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 90
	panel.offset_right = -90
	panel.offset_top = 40
	panel.offset_bottom = -40
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var owed := GameState.talent_points_owed()
	var title := Label.new()
	title.text = "THE CREW — LEVEL %d  ·  %d POINT%s" % [
		GameState.crew_level, owed, "" if owed == 1 else "S"]
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.C_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	outer.add_child(scroll)

	for tier in [1, 2, 3, 4, 5]:
		_build_tier(vbox, tier)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(row)
	# Escape hatch for players who don't want to think about it: deepen
	# whatever the crew has already invested in.
	if owed > 0:
		var auto := Button.new()
		auto.text = "Spend it for me"
		auto.pressed.connect(func():
			var pick := _auto_pick()
			if pick != "":
				_buy(pick))
		row.add_child(auto)
	var close := Button.new()
	close.text = "Done"
	close.pressed.connect(_close)
	row.add_child(close)

func _build_tier(vbox: VBoxContainer, tier: int) -> void:
	var unlocked := Talents.tier_unlocked(tier)
	var header := Label.new()
	header.text = "TIER %d%s" % [tier, "" if unlocked
		else "   —   opens at crew level %d" % int(Talents.TIER_LEVEL[tier])]
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color",
		UITheme.C_ACCENT if unlocked else UITheme.C_MUTED)
	vbox.add_child(header)
	for id in Talents.by_tier(tier):
		var n: Dictionary = Talents.node(id)
		var ranks := Talents.ranks_in(id)
		var max_ranks := int(n["ranks"])
		var reason := Talents.blocked_reason(id)
		var btn := Button.new()
		var rank_tag := "" if max_ranks == 1 else "  [%d/%d]" % [ranks, max_ranks]
		var owned := "  ✓" if ranks >= max_ranks else ""
		btn.text = "%s%s%s — %s%s" % [str(n["name"]), rank_tag, owned,
			str(n["blurb"]), "" if reason == "" else "   (%s)" % reason]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = reason != ""
		if ranks > 0:
			btn.add_theme_color_override("font_disabled_color", UITheme.C_HEAD)
		var node_id := String(id)
		btn.pressed.connect(func(): _buy(node_id))
		vbox.add_child(btn)

## Commit a rank and land it on the live crew immediately — the same
## per-rank path spawn replays, so a purchase never drifts from a reload.
func _buy(id: String) -> void:
	if not GameState.buy_talent(id):
		return
	for member in GameState.squad:
		var c := member as Character
		if c != null and is_instance_valid(c):
			Talents.apply_rank(c, c.display_name.to_lower(), id)
	AudioManager.play_sfx("levelup")
	_build()

## Prefer deepening something already started, then anything affordable.
func _auto_pick() -> String:
	var fallback := ""
	for tier in [1, 2, 3, 4, 5]:
		for id in Talents.by_tier(tier):
			if not Talents.can_buy(str(id)):
				continue
			if Talents.ranks_in(str(id)) > 0:
				return str(id)
			if fallback == "":
				fallback = str(id)
	return fallback
