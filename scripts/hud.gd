class_name DrivingHUD
extends CanvasLayer

signal pause_requested
signal recover_requested
signal sound_requested
signal fps_requested
signal map_orientation_requested
signal continue_requested
signal restart_requested
signal choose_location_requested
signal choose_vehicle_requested
signal home_requested
signal theme_requested(mode: String)

var controls: DriveInput
var car: TouringCar
var navigation: RoadNavigation
var root: Control
var chrome: Control
var map: MiniMap
var map_orientation_button: Button
var speed_label: Label
var city_label: Label
var street_label: Label
var pause_overlay: Control
var settings_overlay: Control
var controls_overlay: Control
var credits_overlay: Control
var card_overlay: Control
var sound_button: Button
var fps_button: Button
var notice: Label
var touch_ids: Dictionary = {}
var touch_buttons: Dictionary = {}
var theme_mode := "dark"
var selected_city_name := "Barcelona"

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	chrome = Control.new()
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chrome)
	get_viewport().size_changed.connect(apply_safe_area)
	apply_safe_area()
	build_chrome()
	build_pause()
	build_settings()
	build_controls()
	build_credits()
	build_card()
	apply_theme(theme_mode)

func apply_safe_area() -> void:
	if root == null:
		return
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.get_name() != "iOS":
		return
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var viewport_size := get_viewport().get_visible_rect().size
	if screen.x <= 0 or screen.y <= 0:
		return
	var factor := viewport_size / Vector2(screen)
	root.offset_left = safe.position.x * factor.x
	root.offset_top = safe.position.y * factor.y
	root.offset_right = -(screen.x - safe.end.x) * factor.x
	root.offset_bottom = -(screen.y - safe.end.y) * factor.y

func apply_theme(mode: String) -> void:
	theme_mode = mode
	if root == null:
		return
	root.theme = UIDesignSystem.theme(mode)
	var c := UIDesignSystem.colors(mode)
	for item in [city_label, street_label, speed_label]:
		if item != null:
			item.add_theme_color_override("font_color", Color.WHITE)
			item.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
			item.add_theme_constant_override("shadow_offset_y", 2)
	for item in root.find_children("*", "Label", true, false):
		if item.get_meta("secondary", false):
			item.add_theme_color_override("font_color", c.secondary)
	if is_instance_valid(pause_overlay):
		for overlay_node in [pause_overlay, settings_overlay, controls_overlay, credits_overlay, card_overlay]:
			overlay_node.color = Color(c.background, 0.97)
	for button_node in get_tree().get_nodes_in_group("primary_ui_button"):
		if is_ancestor_of(button_node):
			UIDesignSystem.primary(button_node, mode)

func set_city_name(value: String) -> void:
	selected_city_name = value
	if city_label != null:
		city_label.text = value

func set_exploring_visible(value: bool) -> void:
	root.visible = value
	if not value:
		release_touches()

func build_chrome() -> void:
	city_label = _label(selected_city_name, 14)
	_place(chrome, city_label, Vector2(28, 24), Vector2(500, 22))
	street_label = _label("", 20)
	street_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	street_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(chrome, street_label, Vector2(28, 46), Vector2(520, 56))
	var pause := _button("Ⅱ", pause_requested.emit)
	pause.tooltip_text = "Pause"
	pause.custom_minimum_size = Vector2(46, 42)
	pause.add_theme_font_size_override("font_size", 19)
	pause.add_theme_stylebox_override("normal", UIDesignSystem.translucent_panel(true, 0.68, 12))
	pause.add_theme_stylebox_override("hover", UIDesignSystem.translucent_panel(true, 0.86, 12))
	_place(chrome, pause, Vector2(-72, 20), Vector2(46, 42), Vector2(1, 0))
	map = MiniMap.new()
	map.car = car
	map.navigation = navigation
	_place(chrome, map, Vector2(-204, 76), Vector2(176, 176), Vector2(1, 0))
	map_orientation_button = _button("N ↑", map_orientation_requested.emit)
	map_orientation_button.tooltip_text = "Lock north up"
	map_orientation_button.custom_minimum_size = Vector2(60, 34)
	map_orientation_button.add_theme_font_size_override("font_size", 13)
	map_orientation_button.add_theme_stylebox_override("normal", UIDesignSystem.translucent_panel(true, 0.68, 10))
	map_orientation_button.add_theme_stylebox_override("hover", UIDesignSystem.translucent_panel(true, 0.86, 10))
	_place(chrome, map_orientation_button, Vector2(-92, 258), Vector2(64, 36), Vector2(1, 0))
	var speed := HBoxContainer.new()
	speed.alignment = BoxContainer.ALIGNMENT_CENTER
	speed.add_theme_constant_override("separation", 7)
	_place(chrome, speed, Vector2(-130, -92), Vector2(260, 62), Vector2(0.5, 1))
	speed_label = _label("0", 52)
	speed.add_child(speed_label)
	var unit := _label("KM/H", 14)
	unit.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	unit.custom_minimum_size.y = 43
	speed.add_child(unit)
	create_pedal("left", "‹", Vector2(24, -132), Vector2(96, 96), Vector2(0, 1))
	create_pedal("right", "›", Vector2(132, -132), Vector2(96, 96), Vector2(0, 1))
	create_pedal("brake", "BRAKE", Vector2(-240, -132), Vector2(96, 96), Vector2(1, 1))
	create_pedal("gas", "DRIVE", Vector2(-132, -132), Vector2(96, 96), Vector2(1, 1))
	var show_touch := OS.has_feature("mobile")
	for pedal in touch_buttons.values():
		pedal.visible = show_touch

func _label(value: String, size: int, secondary := false) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size)
	if secondary:
		result.add_theme_color_override("font_color", UIDesignSystem.colors(theme_mode).secondary)
		result.set_meta("secondary", true)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _button(value: String, action: Callable, primary := false) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 50
	result.pressed.connect(action)
	if primary:
		result.add_to_group("primary_ui_button")
		UIDesignSystem.primary(result, theme_mode)
	return result

func _place(parent: Control, control: Control, offset: Vector2, extent: Vector2, anchor := Vector2.ZERO) -> void:
	parent.add_child(control)
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = offset.x + extent.x
	control.offset_bottom = offset.y + extent.y

func create_pedal(id: String, text: String, offset: Vector2, extent: Vector2, anchor: Vector2) -> void:
	var pedal := _button(text, func(): pass)
	pedal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedal.add_theme_font_size_override("font_size", 16)
	pedal.add_theme_stylebox_override("normal", UIDesignSystem.translucent_panel(true, 0.58, 18))
	_place(chrome, pedal, offset, extent, anchor)
	touch_buttons[id] = pedal

func _input(event: InputEvent) -> void:
	if root == null or not root.visible or controls == null or not controls.enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			assign_touch(event.index, event.position)
		else:
			touch_ids.erase(event.index)
		sync_touches()
	elif event is InputEventScreenDrag:
		assign_touch(event.index, event.position)
		sync_touches()

func assign_touch(id: int, point: Vector2) -> void:
	touch_ids.erase(id)
	for key in touch_buttons:
		if touch_buttons[key].visible and touch_buttons[key].get_global_rect().has_point(point):
			touch_ids[id] = key

func sync_touches() -> void:
	if controls == null:
		return
	for key in controls.held:
		controls.held[key] = key in touch_ids.values()
	for key in touch_buttons:
		touch_buttons[key].modulate = Color(0.72, 0.72, 0.74) if controls.held[key] else Color.WHITE

func release_touches() -> void:
	touch_ids.clear()
	if controls != null:
		controls.clear()
	sync_touches()

func _overlay() -> ColorRect:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	shade.hide()
	return shade

func _column(parent: Control, width := 560.0) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	parent.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(width, maxf(300.0, get_viewport().get_visible_rect().size.x - 48.0))
	center.add_child(panel)
	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 28)
	inner_margin.add_theme_constant_override("margin_right", 28)
	inner_margin.add_theme_constant_override("margin_top", 24)
	inner_margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(inner_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	inner_margin.add_child(column)
	return column

func _title(column: VBoxContainer, title: String, subtitle: String = "") -> void:
	column.add_child(_label(title, 32))
	if not subtitle.is_empty():
		var text := _label(subtitle, 15, true)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(text)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	column.add_child(spacer)

func build_pause() -> void:
	pause_overlay = _overlay()
	var column := _column(pause_overlay)
	_title(column, "City Explorer", "Paused")
	column.add_child(_button("Resume", pause_requested.emit, true))
	column.add_child(_button("Restart from selected location", restart_requested.emit))
	column.add_child(_button("Reset car to nearest road", recover_requested.emit))
	column.add_child(_button("Choose new location", choose_location_requested.emit))
	column.add_child(_button("Choose another car", choose_vehicle_requested.emit))
	column.add_child(_button("Settings", open_settings))
	column.add_child(_button("Exit to Home", home_requested.emit))
	notice = _label("", 13, true)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)

func build_settings() -> void:
	settings_overlay = _overlay()
	var column := _column(settings_overlay)
	_title(column, "Settings")
	column.add_child(_section("Appearance"))
	var appearance := OptionButton.new()
	appearance.custom_minimum_size.y = 48
	for item in ["Dark", "Light", "System"]:
		appearance.add_item(item)
	appearance.item_selected.connect(func(index: int): theme_requested.emit(["dark", "light", "system"][index]))
	column.add_child(appearance)
	column.add_child(_section("Audio"))
	sound_button = _button("Sound On", sound_requested.emit)
	column.add_child(sound_button)
	column.add_child(_section("Performance"))
	fps_button = _button("Frame rate · 30 FPS", fps_requested.emit)
	column.add_child(fps_button)
	column.add_child(_section("Controls"))
	column.add_child(_button("View controls", open_controls))
	column.add_child(_section("Legal"))
	column.add_child(_button("Credits & Licences", open_credits))
	column.add_child(_button("Done", open_pause, true))
	settings_overlay.set_meta("appearance", appearance)

func _section(text: String) -> Label:
	var result := _label(text.to_upper(), 12, true)
	result.custom_minimum_size.y = 22
	return result

func build_controls() -> void:
	controls_overlay = _overlay()
	var column := _column(controls_overlay)
	_title(column, "Controls", "Drive without permanent instructions covering the city.")
	var details := _label("W / ↑   Accelerate\nS / ↓   Brake and reverse\nA D / ← →   Steer\nR   Reset car to road\nC   Reset camera\nP / Esc   Pause", 17)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(details)
	column.add_child(_button("Back to Settings", open_settings, true))

func build_credits() -> void:
	credits_overlay = _overlay()
	var column := _column(credits_overlay, 680)
	_title(column, "Credits & Licences")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 390
	column.add_child(scroll)
	var text := RichTextLabel.new()
	text.fit_content = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 15)
	text.text = "CITY EXPLORER\n© 2026 Hahneysh Kondeti. Original game code and assets.\nThird-party data and assets retain their respective licences.\n\nPlaster004 / Asphalt030: ambientCG.com · CC0 1.0.\nStreet-tree inventory: Ajuntament de Barcelona / Open Data BCN · CC BY 4.0.\nhttps://opendata-ajuntament.barcelona.cat/data/en/dataset/arbrat-viari\n\nLamp positions: Ajuntament de Barcelona / CartoBCN · CC BY 3.0 ES.\nSource updated 2025-12-13; retrieved 2026-09-27. ENE_06_PT survey layer. Coordinates retained; lamp heights, shapes and light output illustrative.\nhttps://creativecommons.org/licenses/by/3.0/es/\n\nMap geometry and park-tree records © OpenStreetMap contributors · ODbL 1.0.\nhttps://www.openstreetmap.org/copyright\nData snapshot: %s\nSource and adapted database are distributed in data/.\n\nTerrain: ICGC MET5 · CC BY 4.0; resampled from 5 m to 6 m.\nhttps://www.icgc.cat\nBare-earth grades; bridge decks and tunnels not reconstructed.\nCoastline: OpenStreetMap; sea and terrain colours illustrative.\nBuilding façades and untagged dimensions are estimated.\n\nLandmark facts: sagradafamilia.org/en/history-of-the-temple\n\nGODOT ENGINE\n%s\n\nTHIRD-PARTY COMPONENTS\n%s\n\nLICENSE TEXTS\n%s" % [str(District.DATA.metadata.retrieved_at), Engine.get_license_text(), JSON.stringify(Engine.get_copyright_info(), "  "), JSON.stringify(Engine.get_license_info(), "  ")]
	if not BuildingAssets.active_credits.is_empty():
		text.text += "\n\nIMPORTED BUILDING ASSETS\n" + "\n\n".join(BuildingAssets.active_credits)
	scroll.add_child(text)
	column.add_child(_button("Back to Settings", open_settings, true))

func build_card() -> void:
	card_overlay = _overlay()
	var column := _column(card_overlay)
	_title(column, District.TITLE, "Landmark discovered")
	var description := _label(District.DESCRIPTION, 17)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	column.add_child(_button("Continue exploring", continue_requested.emit, true))

func _hide_overlays() -> void:
	for item in [pause_overlay, settings_overlay, controls_overlay, credits_overlay, card_overlay]:
		item.hide()

func open_pause() -> void:
	_hide_overlays()
	pause_overlay.show()

func open_settings() -> void:
	_hide_overlays()
	settings_overlay.show()

func open_controls() -> void:
	_hide_overlays()
	controls_overlay.show()

func open_credits() -> void:
	_hide_overlays()
	credits_overlay.show()

func close_all_overlays() -> void:
	_hide_overlays()

func refresh(_discovered: bool, muted: bool, fps: int) -> void:
	if car == null:
		return
	speed_label.text = str(roundi(absf(car.speed) * 3.6)) + (" R" if car.speed < -0.3 else "")
	var nearest := District.nearest_segment(car.global_position)
	street_label.text = nearest.road.name if not nearest.is_empty() else ""
	map_orientation_button.text = "N ↑" if map.north_locked else "↻"
	map_orientation_button.tooltip_text = "North up · locked" if map.north_locked else "Heading up"
	if sound_button != null:
		sound_button.text = "Sound Off" if muted else "Sound On"
	if fps_button != null:
		fps_button.text = "Frame rate · %d FPS" % fps
	var appearance: OptionButton = settings_overlay.get_meta("appearance")
	if appearance != null:
		appearance.select(["dark", "light", "system"].find(theme_mode))
	map.queue_redraw()
