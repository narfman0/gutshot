## The hideout's job board — where a run gets a purpose.
##
## Opened by walking up to the console (the district map stays on M, and
## owed perk picks still take priority; see hideout_site). Shows the open
## contracts when the crew is between jobs, or the standing orders when one
## is live.
class_name JobBoard
extends CanvasLayer

static var _open_instance: JobBoard = null

var _world: GameWorld

static func toggle(parent: Node, world: GameWorld) -> void:
	if _open_instance != null and is_instance_valid(_open_instance):
		_open_instance.queue_free()
		_open_instance = null
		return
	var board := JobBoard.new()
	board.layer = 55
	board._world = world
	parent.add_child(board)
	board._build()
	_open_instance = board

func _close() -> void:
	queue_free()
	_open_instance = null

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
	panel.custom_minimum_size = Vector2(560, 0)
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "JOB BOARD"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.C_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if GameState.active_job != "":
		_build_active(vbox)
	else:
		_build_offers(vbox)

	var close := Button.new()
	close.text = "Done"
	close.pressed.connect(_close)
	vbox.add_child(close)

## Standing orders for the contract already in hand.
func _build_active(vbox: VBoxContainer) -> void:
	var job := Jobs.job(GameState.active_job)
	var head := Label.new()
	head.text = str(job.get("name", "JOB"))
	head.add_theme_font_size_override("font_size", 19)
	head.add_theme_color_override("font_color", UITheme.C_ACCENT)
	vbox.add_child(head)
	var orders := Label.new()
	orders.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orders.custom_minimum_size.x = 520
	orders.add_theme_font_size_override("font_size", 14)
	orders.add_theme_color_override("font_color", UITheme.C_MUTED)
	orders.text = _orders_text(job)
	vbox.add_child(orders)

	var give_up := Button.new()
	give_up.text = "Abandon the job"
	give_up.pressed.connect(func():
		GameState.abandon_job()
		if _world != null and is_instance_valid(_world):
			_world.refresh_job()
		_build())
	vbox.add_child(give_up)

## Open contracts. Completed ones simply stop being listed.
func _build_offers(vbox: VBoxContainer) -> void:
	var open := Jobs.available()
	if open.is_empty():
		var done := Label.new()
		done.text = "Every contract on the board is finished. The district owes you."
		done.add_theme_font_size_override("font_size", 15)
		done.add_theme_color_override("font_color", UITheme.C_MUTED)
		vbox.add_child(done)
		return
	for id in open:
		var job: Dictionary = Jobs.job(id)
		var head := Label.new()
		head.text = "%s  ·  %s  ·  %d XP" % [str(job.get("name", id)),
			_site_name(str(job.get("site", ""))), int(job.get("xp", 0))]
		head.add_theme_font_size_override("font_size", 17)
		head.add_theme_color_override("font_color", UITheme.C_ACCENT)
		vbox.add_child(head)
		var blurb := Label.new()
		blurb.text = str(job.get("blurb", ""))
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size.x = 520
		blurb.add_theme_font_size_override("font_size", 13)
		blurb.add_theme_color_override("font_color", UITheme.C_MUTED)
		vbox.add_child(blurb)
		var take := Button.new()
		take.text = "Take the job"
		var job_id := String(id)
		take.pressed.connect(func():
			if GameState.accept_job(job_id):
				AudioManager.play_sfx("revive")
				if _world != null and is_instance_valid(_world):
					_world.refresh_job()
				_build())
		vbox.add_child(take)

## Standing orders in the contract's own verb. Every job ends the same way —
## get home, get paid — but they do not all start the same way.
func _orders_text(job: Dictionary) -> String:
	var id := GameState.active_job
	var who: String = Factions.NAMES.get(Jobs.owner_of(id), "they")
	var where := "%s, at %s" % [str(job.get("where", "the site")),
		_site_name(str(job.get("site", "")))]
	if GameState.carrying:
		match Jobs.type_of(id):
			"hit":
				return "The mark is down. Carry the proof back to the hideout — %s know it was you." % who
			"sabotage":
				return "The core is out. Get clear and get home — %s are coming." % who
			"escort":
				return "He is walking with you. Get him to the hideout ALIVE; if he dies the contract dies with him. %s are looking." % who
			_:
				return "You have the %s. Get back to the hideout — %s want it back, and they are looking." % [
					str(job.get("loot", "take")), who]
	match Jobs.type_of(id):
		"hit":
			return "Find the mark on %s and put him down. Then bring the proof home." % where
		"sabotage":
			return "Wreck the installation in %s — shoot it, blast it, whatever holds. Then get out." % where
		"escort":
			return "Walk up to him in %s, then walk him home. He does not fight, and he does not survive being left behind." % where
		_:
			return "Take the %s from %s. Then bring it home." % [
				str(job.get("loot", "take")), where]

func _site_name(site_id: String) -> String:
	for entry in DistrictMap.SITES:
		if str(entry.get("id", "")) == site_id:
			return str(entry.get("site_name", site_id))
	return site_id
