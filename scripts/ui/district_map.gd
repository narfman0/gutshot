## The Vantag District map — fast travel between sites (docs/locations.md).
## Toggled with M from any site, or from the hideout's console. Travel is
## instant: pick a site, fade, arrive.
class_name DistrictMap
extends CanvasLayer

const SITES := [
	{"id": "hideout", "site_name": "The Hideout", "blurb": "Safe room. Catch your breath.", "locked": false},
	{"id": "skirmish", "site_name": "The Street", "blurb": "Neon crossroads under the tower. Gang turf.", "locked": false},
	{"id": "depot", "site_name": "Depot 9", "blurb": "Vantag's warehouse — bandit-run. Breach or take the catwalk.", "locked": false},
	{"id": "littlejapan", "site_name": "Little Japan", "blurb": "Market alleys. Clan territory. [LOCKED]", "locked": true},
	{"id": "fab", "site_name": "Fab Level", "blurb": "Assembly machine turf. Neutral — for now.", "locked": false},
	{"id": "tower", "site_name": "Vantag Tower", "blurb": "Something upstairs got out. [LOCKED]", "locked": true},
]

static var _open_instance: DistrictMap = null

static func toggle(parent: Node, current_site: String) -> void:
	if _open_instance != null and is_instance_valid(_open_instance):
		_open_instance.queue_free()
		_open_instance = null
		return
	var map := DistrictMap.new()
	map.layer = 55
	parent.add_child(map)
	map._build(current_site)
	_open_instance = map

func _build(current_site: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = UITheme.theme
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 0)
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "VANTAG DISTRICT"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.C_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	for site in SITES:
		var here: bool = site["id"] == current_site
		var button := Button.new()
		button.text = "%s%s\n%s" % [site["site_name"], "  ◂ YOU ARE HERE" if here else "", site["blurb"]]
		button.disabled = site["locked"] or here
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not button.disabled:
			var target: String = site["id"]
			button.pressed.connect(func():
				queue_free()
				_open_instance = null
				SceneManager.change_level(target))
		vbox.add_child(button)
	var close := Button.new()
	close.text = "Close  (M)"
	close.pressed.connect(func():
		queue_free()
		_open_instance = null)
	vbox.add_child(close)
