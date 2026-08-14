## Autoload — boots the one seamless district scene (with fade) and reloads
## it on retry. There are no per-site scenes anymore: travel inside a run is
## on foot, so the only scene changes left are menu → world and reload.
extends CanvasLayer

const DISTRICT_SCENE := "res://scenes/district.tscn"

var _fade: ColorRect
var _busy := false

func _ready() -> void:
	layer = 100
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

## Fade out and enter the district, crew placed at `site_id`'s anchors.
## The arriving GameWorld calls fade_in() from its _ready.
func start_world(site_id := "hideout") -> void:
	if _busy:
		return
	_busy = true
	GameState.start_site = site_id if site_id != "" else "hideout"
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.25)
	await tween.finished
	get_tree().change_scene_to_file(DISTRICT_SCENE)
	_busy = false

func reload_current() -> void:
	if _busy:
		return
	_busy = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.25)
	await tween.finished
	get_tree().reload_current_scene()
	_busy = false

func fade_in() -> void:
	_fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.25)
