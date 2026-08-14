## The Vantag District map — informational overlay (docs/locations.md).
## Travel is on foot through the connector corridors; this shows where you
## are and what the district holds. Toggled with M from anywhere, or from
## the hideout's console.
class_name DistrictMap
extends CanvasLayer

const SITES := [
	{"id": "hideout", "site_name": "The Hideout", "blurb": "Safe room. Resting here patches the crew up."},
	{"id": "skirmish", "site_name": "The Street", "blurb": "Neon crossroads under the tower. Gang turf."},
	{"id": "exchange", "site_name": "The Exchange", "blurb": "Shuttered market hall — bandits hold the galleries."},
	{"id": "depot", "site_name": "Depot 9", "blurb": "Vantag's warehouse — bandit-run. Breach or take the catwalk."},
	{"id": "fab", "site_name": "Fab Level", "blurb": "Assembly machine turf. Neutral — for now."},
	{"id": "littlejapan", "site_name": "Little Japan", "blurb": "Market alleys. Clan territory. [SEALED]"},
	{"id": "tower", "site_name": "Vantag Tower", "blurb": "Something upstairs got out. [SEALED]"},
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
	panel.custom_minimum_size = Vector2(440, 0)
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "VANTAG DISTRICT"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.C_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "hideout — street — exchange — depot — fab · travel on foot"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UITheme.C_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	for site in SITES:
		var here: bool = site["id"] == current_site
		var name_label := Label.new()
		name_label.text = "%s%s" % [site["site_name"], "  ◂ YOU ARE HERE" if here else ""]
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color",
			UITheme.C_ACCENT if here else UITheme.C_HEAD)
		vbox.add_child(name_label)
		var blurb := Label.new()
		blurb.text = site["blurb"]
		blurb.add_theme_font_size_override("font_size", 13)
		blurb.add_theme_color_override("font_color", UITheme.C_MUTED)
		vbox.add_child(blurb)
	var close := Button.new()
	close.text = "Close  (M)"
	close.pressed.connect(func():
		queue_free()
		_open_instance = null)
	vbox.add_child(close)
