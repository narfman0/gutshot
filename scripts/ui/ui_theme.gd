## Gutshot UI Theme — builds and exposes a shared Theme resource.
## UI nodes pick it up via `self.theme = UITheme.theme` (inherited by children).
## Palette: grimdark cyberpunk — near-black panels, neon cyan borders, magenta
## accents. Sprite-based HUD elements (Synty INTERFACE pack) sit on top of
## this; the Theme covers text, buttons, bars, and panel chrome.
extends Node

## The shared theme — built once at startup.
var theme: Theme

## Colour palette
const C_BG         := Color(0.04, 0.05, 0.07, 0.94)  # near-black panel
const C_BG_LIGHT   := Color(0.08, 0.10, 0.14, 0.94)  # slightly lighter panels
const C_BORDER     := Color(0.10, 0.75, 0.85)         # neon cyan border
const C_BORDER_DIM := Color(0.08, 0.38, 0.44, 0.7)   # dimmed border (inactive)
const C_ACCENT     := Color(0.95, 0.25, 0.75)         # magenta accent / active
const C_HEAD       := Color(0.55, 0.95, 1.00)         # cyan headings / labels
const C_BODY       := Color(0.82, 0.86, 0.90)         # cool-white body text
const C_MUTED      := Color(0.45, 0.50, 0.55)         # muted / secondary text
const C_HP         := Color(0.20, 0.85, 0.45)         # health green
const C_HP_BG      := Color(0.08, 0.14, 0.10)         # health bar trough
const C_HP_ENEMY   := Color(0.90, 0.22, 0.25)         # enemy health red
const C_SHIELD     := Color(0.35, 0.65, 1.00)         # shield blue (v1: stub)
const C_FOCUS      := Color(0.12, 0.55, 0.65, 0.55)  # hover / focus highlight
const C_PRESS      := Color(0.06, 0.30, 0.38, 0.80)  # pressed state

func _ready() -> void:
	theme = _build()

func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15

	t.set_stylebox("panel", "Panel", _panel_box(C_BG, C_BORDER, 2, 3))
	t.set_stylebox("panel", "PanelContainer", _panel_box(C_BG, C_BORDER, 2, 3))

	t.set_color("font_color", "Label", C_BODY)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	t.set_color("font_color", "Button", C_HEAD)
	t.set_color("font_hover_color", "Button", C_HEAD.lightened(0.15))
	t.set_color("font_pressed_color", "Button", C_HEAD.darkened(0.15))
	t.set_color("font_disabled_color", "Button", C_MUTED)
	t.set_stylebox("normal", "Button", _btn_box(C_BG_LIGHT, C_BORDER, 2, 3))
	t.set_stylebox("hover", "Button", _btn_box(C_FOCUS, C_BORDER, 2, 3))
	t.set_stylebox("pressed", "Button", _btn_box(C_PRESS, C_BORDER_DIM, 2, 3))
	t.set_stylebox("disabled", "Button", _btn_box(C_BG, C_BORDER_DIM, 1, 3))
	t.set_stylebox("focus", "Button", _empty_box())

	t.set_stylebox("background", "ProgressBar", _panel_box(C_HP_BG, C_BORDER_DIM, 1, 2))
	t.set_stylebox("fill", "ProgressBar", _fill_box(C_HP))
	t.set_color("font_color", "ProgressBar", C_BODY)

	t.set_stylebox("panel", "ScrollContainer", _panel_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))

	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_BORDER_DIM
	sep_style.set_content_margin_all(1)
	t.set_stylebox("separator", "HSeparator", sep_style)

	return t

# ── StyleBox helpers ─────────────────────────────────────────────────────────

static func _panel_box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(6)
	return s

static func _btn_box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin(SIDE_LEFT, 12)
	s.set_content_margin(SIDE_RIGHT, 12)
	s.set_content_margin(SIDE_TOP, 6)
	s.set_content_margin(SIDE_BOTTOM, 6)
	return s

static func _fill_box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(2)
	s.set_content_margin_all(0)
	return s

static func _empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()
