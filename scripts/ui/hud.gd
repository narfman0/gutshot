## Mission HUD — squad portrait strip (bottom-left), weapon slot bar
## (bottom-center), overhead health bars. Chrome comes from
## the Synty INTERFACE_SciFi_Soldier_HUD sprite pack (fetched into assets/ui/
## from the asset server's raw tree); bars/text ride on UITheme.
## Portraits carry an empty shield segment and a status-effect icon row —
## v1 stubs so the layout is ready when shields/status land.
class_name Hud
extends CanvasLayer

# Full res:// literals on purpose — fetch_assets.sh's used-only scan only
# resolves complete paths (a prefix-const concatenation is invisible to it).
const SPR_PANEL := "res://assets/ui/INTERFACE_SciFi_Soldier_HUD_Source_Sprites_v2/Source_Sprites/Sprites/HUD/SPR_HUD_SciFi_Box_A.png"
const SPR_SLOT := "res://assets/ui/INTERFACE_SciFi_Soldier_HUD_Source_Sprites_v2/Source_Sprites/Sprites/HUD/SPR_HUD_SciFi_Box_Slanted.png"
## gear display_name → weapon icon sprite.
const WEAPON_ICONS := {
	"SMG": "res://assets/ui/INTERFACE_SciFi_Soldier_HUD_Source_Sprites_v2/Source_Sprites/Sprites/Icons_Weapons/ICON_SM_Wep_SMG_01_SciFiCyberCity.png",
	"Rifle": "res://assets/ui/INTERFACE_SciFi_Soldier_HUD_Source_Sprites_v2/Source_Sprites/Sprites/Icons_Weapons/ICON_SM_Wep_Rifle_01_SciFiCyberCity.png",
	"Pistol": "res://assets/ui/INTERFACE_SciFi_Soldier_HUD_Source_Sprites_v2/Source_Sprites/Sprites/Icons_Weapons/ICON_SM_Wep_Pistol_01_SciFiCyberCity.png",
	"Frag Belt": "res://assets/ui/INTERFACE_SciFi_Soldier_HUD_Source_Sprites_v2/Source_Sprites/Sprites/Icons_Explosives/ICON_SM_Wep_Grenade_01_SciFiCyberCity.png",
	"Heal Gun": "res://assets/ui/INTERFACE_SciFi_Soldier_HUD_Source_Sprites_v2/Source_Sprites/Sprites/Icons_Weapons/ICON_SM_Wep_Rifle_Laser_01_SciFiCity.png",
}

const PORTRAIT_SIZE := Vector2(150, 84)
const SLOT_SIZE := Vector2(84, 68)
const OVERHEAD_SIZE := Vector2(46, 5)

var _squad: Squad
var _objectives: ObjectiveManager
var _camera: Camera3D

var _portraits: Array = []       # per member: {panel, hp, shield, status_row}
var _slots: Array = []           # per slot: {box, icon, cooldown, key}
var _overheads: Dictionary = {}  # Character → ProgressBar

func setup(squad: Squad, objectives: ObjectiveManager, camera: Camera3D,
		site_name := "") -> void:
	_squad = squad
	_objectives = objectives
	_camera = camera
	layer = 10
	_build_portraits()
	_build_weapon_bar()
	if site_name != "":
		_build_site_label(site_name)
	_apply_crosshair_cursor()
	_squad.active_changed.connect(func(_i, _c): _refresh_portraits(); _refresh_slots())
	for member in _squad.members:
		(member as Character).hp_changed.connect(func(_h, _m): _refresh_portraits())
		(member as Character).shield_changed.connect(func(_s, _m): _refresh_portraits())
		(member as Character).weapon_changed.connect(func(_s): _refresh_slots())
	for c in _squad.get_tree().get_nodes_in_group("characters"):
		_add_overhead(c as Character)
	_refresh_portraits()
	_refresh_slots()

func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

## Nine-patch panel from the pack, falling back to a themed Panel when the
## sprites aren't fetched (headless CI).
func _panel(size: Vector2) -> Control:
	var tex := _texture(SPR_PANEL)
	if tex == null:
		var p := Panel.new()
		p.theme = UITheme.theme
		p.custom_minimum_size = size
		return p
	var nine := NinePatchRect.new()
	nine.texture = tex
	nine.custom_minimum_size = size
	# Patch margins are screen pixels as well as texture pixels — a margin
	# larger than the control inflates its minimum size past `size`.
	var margin := int(minf(minf(tex.get_width(), tex.get_height()) / 3.0,
		minf(size.x, size.y) / 3.0))
	nine.patch_margin_left = margin
	nine.patch_margin_right = margin
	nine.patch_margin_top = margin
	nine.patch_margin_bottom = margin
	return nine

# ── Portrait strip ───────────────────────────────────────────────────────────

func _build_portraits() -> void:
	var strip := HBoxContainer.new()
	strip.name = "PortraitStrip"
	strip.theme = UITheme.theme
	strip.add_theme_constant_override("separation", 8)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	strip.position = Vector2(16, -16 - PORTRAIT_SIZE.y)
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(strip)
	for i in _squad.members.size():
		var member: Character = _squad.members[i]
		var panel := _panel(PORTRAIT_SIZE)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var index := i
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				_squad.set_active(index))
		strip.add_child(panel)
		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 14
		vbox.offset_right = -14
		vbox.offset_top = 12
		vbox.offset_bottom = -10
		vbox.add_theme_constant_override("separation", 3)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(vbox)
		var name_label := Label.new()
		name_label.text = member.display_name
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_label)
		# Regenerating shield layer above health.
		var shield := ProgressBar.new()
		shield.custom_minimum_size = Vector2(0, 6)
		shield.show_percentage = false
		shield.max_value = maxf(member.max_shield, 1.0)
		shield.value = member.shield
		shield.add_theme_stylebox_override("fill", UITheme._fill_box(UITheme.C_SHIELD))
		shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(shield)
		var hp := ProgressBar.new()
		hp.custom_minimum_size = Vector2(0, 12)
		hp.show_percentage = false
		hp.max_value = member.max_hp
		hp.value = member.hp
		hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(hp)
		# Status-effect icon row — empty container reserved for post-v1 effects.
		var status_row := HBoxContainer.new()
		status_row.custom_minimum_size = Vector2(0, 18)
		status_row.add_theme_constant_override("separation", 2)
		status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(status_row)
		_portraits.append({"panel": panel, "hp": hp, "shield": shield, "status_row": status_row})

func _refresh_portraits() -> void:
	for i in _portraits.size():
		var member: Character = _squad.members[i]
		var entry: Dictionary = _portraits[i]
		(entry["hp"] as ProgressBar).value = member.hp
		(entry["shield"] as ProgressBar).value = member.shield
		var active: bool = i == _squad.active_index
		var panel := entry["panel"] as Control
		panel.modulate = Color(1, 1, 1, 1.0) if active else Color(0.75, 0.75, 0.75, 0.85)
		if not member.is_alive():
			panel.modulate = Color(0.45, 0.25, 0.25, 0.7)

# ── Weapon slot bar ──────────────────────────────────────────────────────────

func _build_weapon_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "WeaponBar"
	bar.theme = UITheme.theme
	bar.add_theme_constant_override("separation", 8)
	# Anchor to bottom-center and pull the box fully above the screen edge —
	# a bare position override fights the container's own layout.
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -1.5 * SLOT_SIZE.x - 8.0
	bar.offset_right = 1.5 * SLOT_SIZE.x + 8.0
	bar.offset_top = -16.0 - SLOT_SIZE.y
	bar.offset_bottom = -16.0
	add_child(bar)
	for i in 3:
		var box := _panel(SLOT_SIZE)
		bar.add_child(box)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8
		icon.offset_right = -8
		icon.offset_top = 8
		icon.offset_bottom = -8
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)
		# Cooldown sweep: a dark overlay that drains upward as the timer runs.
		var cooldown := ColorRect.new()
		cooldown.color = Color(0, 0, 0, 0.65)
		cooldown.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cooldown)
		var key := Label.new()
		key.text = str(i + 1)
		key.position = Vector2(6, 2)
		key.add_theme_font_size_override("font_size", 13)
		key.add_theme_color_override("font_color", UITheme.C_HEAD)
		box.add_child(key)
		var ammo := Label.new()
		ammo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		ammo.position = Vector2(-34, -22)
		ammo.add_theme_font_size_override("font_size", 13)
		ammo.add_theme_color_override("font_color", UITheme.C_BODY)
		box.add_child(ammo)
		_slots.append({"box": box, "icon": icon, "cooldown": cooldown, "ammo": ammo})

func _refresh_slots() -> void:
	var active := _squad.active_character()
	if active == null:
		return
	for i in 3:
		var entry: Dictionary = _slots[i]
		var gear: GearItem = active.gear_slots[i]
		var icon := entry["icon"] as TextureRect
		icon.texture = _texture(WEAPON_ICONS.get(gear.display_name, "")) if gear != null else null
		var box := entry["box"] as Control
		box.modulate = Color(1, 1, 1) if i == active.active_slot else Color(0.6, 0.65, 0.7, 0.85)

var _site_label: Label = null
var _xp_label: Label = null
var _job_label: Label = null
var _job_flash: Label = null

## Site name top-left — instant orientation as the crew crosses the district.
## The XP line rides underneath: level, pool progress, and the train nudge.
func _build_site_label(site_name: String) -> void:
	_site_label = Label.new()
	_site_label.theme = UITheme.theme
	_site_label.text = site_name
	_site_label.add_theme_font_size_override("font_size", 22)
	_site_label.add_theme_color_override("font_color", UITheme.C_HEAD)
	_site_label.position = Vector2(18, 12)
	add_child(_site_label)
	_xp_label = Label.new()
	_xp_label.theme = UITheme.theme
	_xp_label.add_theme_font_size_override("font_size", 13)
	_xp_label.add_theme_color_override("font_color", UITheme.C_MUTED)
	_xp_label.position = Vector2(18, 42)
	add_child(_xp_label)
	_job_label = Label.new()
	_job_label.theme = UITheme.theme
	_job_label.add_theme_font_size_override("font_size", 14)
	_job_label.position = Vector2(18, 60)
	add_child(_job_label)
	GameState.xp_changed.connect(func(_t): _refresh_xp())
	GameState.crew_leveled.connect(func(_l): _refresh_xp())
	GameState.job_changed.connect(_refresh_job)
	_refresh_xp()
	_refresh_job()

func _refresh_xp() -> void:
	if _xp_label == null:
		return
	var lvl := GameState.crew_level
	var text := "LVL %d" % lvl
	if lvl < GameState.LEVEL_CAP:
		text += "  ·  XP %d / %d" % [GameState.xp, GameState.threshold_for(lvl + 1)]
	if GameState.talent_points_owed() > 0:
		text += "  ·  TRAIN AT THE HIDEOUT"
		_xp_label.add_theme_color_override("font_color", UITheme.C_ACCENT)
	else:
		_xp_label.add_theme_color_override("font_color", UITheme.C_MUTED)
	_xp_label.text = text

## The standing order, one line. Between jobs it says nothing at all rather
## than saying "no job" — an empty line is quieter than a nag.
func _refresh_job() -> void:
	if _job_label == null:
		return
	if GameState.active_job == "":
		_job_label.text = ""
		return
	var job := Jobs.job(GameState.active_job)
	if GameState.carrying:
		_job_label.text = "JOB · CARRYING THE %s — GET TO THE HIDEOUT" % str(
			job.get("loot", "TAKE")).to_upper()
		_job_label.add_theme_color_override("font_color", UITheme.C_ACCENT)
	else:
		_job_label.text = "JOB · %s — %s" % [str(job.get("name", "")),
			str(job.get("where", ""))]
		_job_label.add_theme_color_override("font_color", UITheme.C_HEAD)

## Centre-screen beat for the two moments that matter: the lift and the
## delivery. Fades itself out — this is the replacement for the AREA CLEAR
## popup we deleted, and it lands on the player's own actions.
func flash_job(text: String) -> void:
	if _job_flash != null and is_instance_valid(_job_flash):
		_job_flash.queue_free()
	_job_flash = Label.new()
	_job_flash.theme = UITheme.theme
	_job_flash.text = text
	_job_flash.add_theme_font_size_override("font_size", 30)
	_job_flash.add_theme_color_override("font_color", UITheme.C_ACCENT)
	_job_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_job_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_job_flash.anchor_right = 1.0
	_job_flash.offset_top = 120
	add_child(_job_flash)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_job_flash, "modulate:a", 0.0, 1.2)
	tween.tween_callback(func():
		if _job_flash != null and is_instance_valid(_job_flash):
			_job_flash.queue_free()
			_job_flash = null)

## GameWorld calls this when the active character crosses into a site.
func set_site(site_name: String) -> void:
	if _site_label != null:
		_site_label.text = site_name

var _reticle: TextureRect = null

## A drawn crosshair — the cursor in iso mode, and the same texture pinned
## center-screen as the OTS reticle whenever the mouse is captured.
func _apply_crosshair_cursor() -> void:
	var size := 25
	var mid := size / 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var main := Color(0.55, 0.95, 1.0, 0.95)
	var shadow := Color(0, 0, 0, 0.8)
	for offset in range(-1, 2):
		for i in range(size):
			var gap: bool = absi(i - mid) < 4  # open center so the target stays visible
			if gap:
				continue
			img.set_pixel(i, clampi(mid + offset, 0, size - 1), shadow if offset != 0 else main)
			img.set_pixel(clampi(mid + offset, 0, size - 1), i, shadow if offset != 0 else main)
	img.set_pixel(mid, mid, main)
	var tex := ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(mid, mid))
	_reticle = TextureRect.new()
	_reticle.texture = tex
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.visible = false
	add_child(_reticle)

# ── Overhead bars ────────────────────────────────────────────────────────────

## Overhead bars are raw ColorRects (trough + fill), not ProgressBars — a
## themed ProgressBar refuses to shrink below its stylebox minimum and renders
## as a giant slab at this size.
func _add_overhead(character: Character) -> void:
	if character == null or _overheads.has(character):
		return
	var trough := ColorRect.new()
	trough.color = Color(0, 0, 0, 0.6)
	trough.size = OVERHEAD_SIZE
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = Factions.COLORS.get(character.team, UITheme.C_HP_ENEMY)
	fill.position = Vector2.ONE
	fill.size = OVERHEAD_SIZE - Vector2(2, 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.add_child(fill)
	add_child(trough)
	_overheads[character] = trough
	character.hp_changed.connect(func(hp, max_hp):
		if is_instance_valid(fill):
			fill.size.x = (OVERHEAD_SIZE.x - 2.0) * clampf(hp / max_hp, 0.0, 1.0))
	character.character_died.connect(func(_c):
		if is_instance_valid(trough):
			trough.visible = false)

func _process(_delta: float) -> void:
	if _camera == null:
		return
	if _reticle != null:
		_reticle.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	for character in _overheads:
		var bar: ColorRect = _overheads[character]
		if not is_instance_valid(character) or not is_instance_valid(bar) or not bar.visible:
			continue
		# A character on a hidden floor takes their overhead bar with them
		# (modulate, not visible — death owns the visible flag).
		bar.modulate.a = 1.0 if (character as Node3D).visible else 0.0
		if bar.modulate.a == 0.0:
			continue
		var world := (character as Node3D).global_position \
			+ Vector3(0, 2.1 * Character.VERTICAL_SQUASH, 0)
		if _camera.is_position_behind(world):
			bar.visible = false
			continue
		bar.position = _camera.unproject_position(world) - OVERHEAD_SIZE * 0.5
	# Cooldown / reload sweep + ammo counters for the active character.
	var active := _squad.active_character() if _squad != null else null
	if active == null:
		return
	var shooter: Shooter = active.get_node("Shooter")
	for i in 3:
		var entry: Dictionary = _slots[i]
		var cooldown := entry["cooldown"] as ColorRect
		var ammo := entry["ammo"] as Label
		var gear: GearItem = active.gear_slots[i]
		var frac := 0.0
		if gear != null and not gear.abilities.is_empty():
			var ability: Ability = gear.abilities[0]
			frac = clampf(active.cooldown_remaining(ability) / maxf(ability.cooldown, 0.01), 0.0, 1.0)
		if i == active.active_slot and shooter.is_reloading():
			frac = maxf(frac, shooter.reload_frac())
		cooldown.offset_top = -SLOT_SIZE.y * frac
		cooldown.visible = frac > 0.0
		if gear != null and gear.mag_size > 0:
			ammo.text = "%d/%d" % [maxi(shooter.mag_left(i), 0), gear.mag_size]
		else:
			ammo.text = ""
