## Autoload — scene transitions with fade, and the mission-id → scene registry.
extends CanvasLayer

const LEVELS := {
	"skirmish": "res://scenes/levels/skirmish.tscn",
}

var _fade: ColorRect
var _busy := false

func _ready() -> void:
	layer = 100
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

func level_scene_for(mission_id: String) -> String:
	return LEVELS.get(mission_id, LEVELS["skirmish"])

## Fade out and switch scenes. The arriving GameWorld calls fade_in() from
## its _ready.
func change_level(mission_id: String) -> void:
	if _busy:
		return
	_busy = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.25)
	await tween.finished
	get_tree().change_scene_to_file(level_scene_for(mission_id))
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
