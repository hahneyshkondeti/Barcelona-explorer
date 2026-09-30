class_name UIDesignSystem
extends RefCounted

const DARK := {
	"background": Color("121212"),
	"surface": Color("1c1c1e"),
	"surface_high": Color("2c2c2e"),
	"text": Color("f5f5f7"),
	"secondary": Color("a1a1a6"),
	"divider": Color("3a3a3c"),
	"accent": Color("ffffff"),
	"on_accent": Color("111111"),
}

const LIGHT := {
	"background": Color("f5f5f7"),
	"surface": Color("ffffff"),
	"surface_high": Color("e9e9ed"),
	"text": Color("171717"),
	"secondary": Color("68686d"),
	"divider": Color("d5d5d9"),
	"accent": Color("171717"),
	"on_accent": Color("ffffff"),
}

static func resolved_mode(mode: String) -> String:
	if mode == "system":
		return "dark" if DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode() else "light"
	return mode if mode in ["dark", "light"] else "dark"

static func colors(mode: String) -> Dictionary:
	return DARK if resolved_mode(mode) == "dark" else LIGHT

static func box(color: Color, radius: int = 14, border_color := Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.border_color = border_color
	result.set_border_width_all(border_width)
	result.content_margin_left = 18
	result.content_margin_right = 18
	result.content_margin_top = 12
	result.content_margin_bottom = 12
	return result

static func theme(mode: String) -> Theme:
	var c := colors(mode)
	var result := Theme.new()
	result.default_font_size = 17
	result.set_color("font_color", "Label", c.text)
	result.set_color("font_color", "Button", c.text)
	result.set_color("font_hover_color", "Button", c.text)
	result.set_color("font_pressed_color", "Button", c.text)
	result.set_color("font_focus_color", "Button", c.text)
	result.set_color("font_disabled_color", "Button", c.secondary.darkened(0.2))
	result.set_stylebox("normal", "Button", box(c.surface_high, 12))
	result.set_stylebox("hover", "Button", box(c.surface_high.lightened(0.08), 12))
	result.set_stylebox("pressed", "Button", box(c.surface_high.darkened(0.08), 12))
	result.set_stylebox("disabled", "Button", box(c.surface, 12))
	result.set_stylebox("focus", "Button", box(Color.TRANSPARENT, 12, c.text, 2))
	result.set_color("font_color", "LineEdit", c.text)
	result.set_color("font_placeholder_color", "LineEdit", c.secondary)
	result.set_color("caret_color", "LineEdit", c.text)
	result.set_stylebox("normal", "LineEdit", box(c.surface_high, 12))
	result.set_stylebox("focus", "LineEdit", box(c.surface_high, 12, c.text, 2))
	result.set_color("font_color", "OptionButton", c.text)
	result.set_stylebox("normal", "OptionButton", box(c.surface_high, 12))
	result.set_stylebox("hover", "OptionButton", box(c.surface_high.lightened(0.08), 12))
	result.set_stylebox("focus", "OptionButton", box(Color.TRANSPARENT, 12, c.text, 2))
	result.set_stylebox("panel", "PanelContainer", box(c.surface, 18))
	result.set_color("font_color", "RichTextLabel", c.text)
	result.set_color("default_color", "RichTextLabel", c.text)
	result.set_color("font_color", "ItemList", c.text)
	result.set_color("font_selected_color", "ItemList", c.on_accent)
	result.set_stylebox("panel", "ItemList", box(c.surface, 14))
	result.set_stylebox("selected", "ItemList", box(c.accent, 10))
	result.set_stylebox("selected_focus", "ItemList", box(c.accent, 10))
	return result

static func primary(button: Button, mode: String) -> void:
	var c := colors(mode)
	button.add_theme_stylebox_override("normal", box(c.accent, 12))
	button.add_theme_stylebox_override("hover", box(c.accent.darkened(0.08) if resolved_mode(mode) == "light" else c.accent.darkened(0.12), 12))
	button.add_theme_stylebox_override("pressed", box(c.accent.darkened(0.18), 12))
	button.add_theme_color_override("font_color", c.on_accent)
	button.add_theme_color_override("font_hover_color", c.on_accent)
	button.add_theme_color_override("font_pressed_color", c.on_accent)
	button.add_theme_color_override("font_focus_color", c.on_accent)
	button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, 12, c.secondary, 2))

static func translucent_panel(dark: bool = true, alpha: float = 0.78, radius: int = 14) -> StyleBoxFlat:
	return box(Color(0.05, 0.05, 0.06, alpha) if dark else Color(1, 1, 1, alpha), radius)
