class_name DrivingHUD
extends CanvasLayer

signal pause_requested
signal recover_requested
signal sound_requested
signal fps_requested
signal map_orientation_requested
signal place_requested(place: Dictionary)
signal area_requested(index: int)
signal start_requested(point: Vector3)
signal continue_requested

var controls: DriveInput
var car: TouringCar
var navigation: RoadNavigation
var root: Control
var map: MiniMap
var map_orientation_button: Button
var speed_label: Label
var route_label: Label
var pause_overlay: Control
var card_overlay: Control
var sound_button: Button
var fps_button: Button
var touch_rects: Dictionary = {}
var touch_ids: Dictionary = {}
var touch_buttons: Dictionary = {}
var notice: Label
var credits: AcceptDialog
var places_overlay: Control
var places_list: ItemList
var places_info: RichTextLabel
var place_search: LineEdit
var filtered_places: Array = []
var selected_place: Dictionary = {}
var route_place_button: Button
var street_label: Label
var start_place_button: Button
var address_lookup := AddressSearch.new()
var search_timer: Timer
var map_overlay: Control
var city_map: CityMap
var map_info: Label
var map_start_button: Button
var map_target := Vector3.INF

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	get_viewport().size_changed.connect(apply_safe_area)
	apply_safe_area()
	var theme := Theme.new()
	theme.default_font_size = 18
	root.theme = theme
	var pause := button("Ⅱ", pause_requested.emit)
	pause.custom_minimum_size = Vector2(48, 44)
	pause.tooltip_text = "Pause"
	pause.add_theme_font_size_override("font_size", 22)
	var pause_style := style(Color(0.08, 0.18, 0.20, 0.48))
	pause_style.content_margin_top = 6
	pause_style.content_margin_bottom = 6
	pause_style.content_margin_left = 12
	pause_style.content_margin_right = 12
	pause.add_theme_stylebox_override("normal", pause_style)
	place(pause, Vector2(-76, 20), Vector2(48, 44), Vector2(1, 0))
	map = MiniMap.new()
	map.car = car
	map.navigation = navigation
	place(map, Vector2(-212, 88), Vector2(184, 184), Vector2(1, 0))
	var expand_map := button("", open_map)
	place(expand_map, Vector2(-212, 88), Vector2(184, 184), Vector2(1, 0))
	for state in ["normal", "hover", "pressed"]:
		expand_map.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	street_label = label("", 18)
	street_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place(street_label, Vector2(28, 26), Vector2(640, 60))
	var speed := HBoxContainer.new()
	speed.alignment = BoxContainer.ALIGNMENT_CENTER
	speed.add_theme_constant_override("separation", 6)
	place(speed, Vector2(-120, -104), Vector2(240, 76), Vector2(0.5, 1))
	speed_label = label("0", 56)
	speed.add_child(speed_label)
	var units := label("KM/H", 15)
	units.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	units.add_theme_constant_override("outline_size", 2)
	speed.add_child(units)
	create_pedal("left", "◀", Vector2(30, -143), Vector2(112, 112), Vector2(0, 1))
	create_pedal("right", "▶", Vector2(156, -143), Vector2(112, 112), Vector2(0, 1))
	create_pedal("brake", "BRAKE\nREVERSE", Vector2(-283, -143), Vector2(112, 112), Vector2(1, 1))
	create_pedal("gas", "DRIVE\n↑", Vector2(-155, -166), Vector2(126, 135), Vector2(1, 1))
	build_pause()
	build_card()
	build_credits()
	build_places()
	build_city_map()

func apply_safe_area() -> void:
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

func label(text: String, font_size: int, color: Color = Color("fff8e6")) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color(0.08, 0.16, 0.17, 0.8))
	result.add_theme_constant_override("shadow_offset_y", 1)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func style(color: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(14)
	result.content_margin_left = 18
	result.content_margin_right = 18
	result.content_margin_top = 12
	result.content_margin_bottom = 12
	return result

func button(text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(100, 48)
	result.add_theme_stylebox_override("normal", style(Color("25494e")))
	result.add_theme_stylebox_override("hover", style(Color("376067")))
	result.add_theme_stylebox_override("pressed", style(Color("9c6a40")))
	result.add_theme_color_override("font_color", Color("fff5dc"))
	result.focus_mode = Control.FOCUS_NONE
	result.pressed.connect(action)
	return result

func place(control: Control, offset: Vector2, extent: Vector2, anchor: Vector2 = Vector2.ZERO) -> void:
	root.add_child(control)
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = offset.x + extent.x
	control.offset_bottom = offset.y + extent.y

func create_pedal(id: String, text: String, offset: Vector2, extent: Vector2, anchor: Vector2) -> void:
	var pedal := button(text, func(): pass)
	place(pedal, offset, extent, anchor)
	pedal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_buttons[id] = pedal

func _input(event: InputEvent) -> void:
	if not controls.enabled:
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
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			assign_touch(-1, event.position)
		else:
			touch_ids.erase(-1)
		sync_touches()
	elif event is InputEventMouseMotion and touch_ids.has(-1):
		assign_touch(-1, event.position)
		sync_touches()

func assign_touch(id: int, point: Vector2) -> void:
	touch_ids.erase(id)
	for key in touch_buttons:
		if touch_buttons[key].get_global_rect().has_point(point):
			touch_ids[id] = key

func sync_touches() -> void:
	for key in controls.held:
		controls.held[key] = key in touch_ids.values()
	for key in touch_buttons:
		touch_buttons[key].modulate = Color("ffcb79") if controls.held[key] else Color.WHITE

func release_touches() -> void:
	touch_ids.clear()
	controls.clear()
	sync_touches()

func overlay() -> PanelContainer:
	var shade := PanelContainer.new()
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_theme_stylebox_override("panel", style(Color(0.06, 0.13, 0.15, 0.96)))
	shade.hide()
	return shade

func centered_column(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	parent.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(600, 0)
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	return column

func build_pause() -> void:
	pause_overlay = overlay()
	var column := centered_column(pause_overlay)
	column.add_child(label("City Explorer", 30))
	column.add_child(label("PAUSED  /  BARCELONA", 13, Color("e8c281")))
	column.add_child(button("Continue exploring", pause_requested.emit))
	column.add_child(button("Reset car to a safe road", recover_requested.emit))
	var areas := HBoxContainer.new()
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for area in District.AREAS: picker.add_item(area.name)
	areas.add_child(picker)
	areas.add_child(button("Start in district", func(): area_requested.emit(picker.selected)))
	column.add_child(areas)
	sound_button = button("Sound: on", sound_requested.emit)
	column.add_child(sound_button)
	fps_button = button("Frame cap: 30 FPS", fps_requested.emit)
	column.add_child(fps_button)
	notice = label("", 13)
	column.add_child(notice)
	column.add_child(label("© 2026 Hahneysh Kondeti · City Explorer\nMap © OpenStreetMap contributors · ODbL\nTerrain: ICGC · Trees: Open Data BCN · CC BY 4.0\nLamp positions: CartoBCN · CC BY 3.0 ES", 12))
	column.add_child(button("Credits & licenses", func(): credits.popup_centered(Vector2i(900, 560))))
	column.add_child(label("WASD / arrows · Brake held at rest = reverse\nR: recover car   C: reset camera   P / Esc: pause\nOpenStreetMap snapshot · Generated façade appearance", 13))

func build_card() -> void:
	card_overlay = overlay()
	var column := centered_column(card_overlay)
	column.add_child(label("01  /  A CITY IMAGINED IN STONE", 14, Color("e8c281")))
	column.add_child(label(District.TITLE, 42))
	var description := label(District.DESCRIPTION, 19)
	description.custom_minimum_size = Vector2(600, 0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	column.add_child(label("LANDMARK DISCOVERED  ·  Saved on this device", 14, Color("e8c281")))
	column.add_child(button("Continue exploring", continue_requested.emit))

func refresh(_discovered: bool, muted: bool, fps: int) -> void:
	speed_label.text = str(roundi(absf(car.speed) * 3.6))
	if car.speed < -0.3:
		speed_label.text += "  R"
	route_label.text = "Follow the gold route · %d m" % roundi(navigation.distance_remaining()) if navigation.active else "Free exploration · select a destination"
	if car.global_position.distance_to(District.DESTINATION) < 20:
		route_label.text = "Slow to a stop in the gold arrival ring"
	sound_button.text = "Sound: off" if muted else "Sound: on"
	fps_button.text = "Frame cap: %d FPS" % fps
	street_label.text = District.nearest_segment(car.global_position).road.name
	if TerrainData.is_estimated(car.global_position): street_label.text += " · approximate coastal elevation"
	if navigation.active:
		route_label.text = "%s · %d m by road" % [navigation.destination_name, roundi(navigation.distance_remaining())]
		if not navigation.reachable:
			route_label.text = "No permitted route inside this map extract"
		elif car.position.distance_to(navigation.destination) < 15:
			route_label.text = "Destination nearby · slow to a stop"
	map_orientation_button.text = "North up · locked" if map.north_locked else "Heading up"
	map.queue_redraw()

func build_credits() -> void:
	credits = AcceptDialog.new()
	credits.title = "City Explorer · Credits & licenses"
	credits.dialog_text = ""
	root.add_child(credits)
	var text := RichTextLabel.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 20
	text.offset_top = 16
	text.offset_right = -20
	text.offset_bottom = -60
	text.add_theme_font_size_override("normal_font_size", 16)
	text.text = "CITY EXPLORER\n© 2026 Hahneysh Kondeti. Original game code and assets.\nThird-party data and assets retain their respective licenses.\nOriginal procedural appearance, interface and synthesized audio.\nPlaster004 / Asphalt030 materials: ambientCG.com · CC0 1.0.\nStreet-tree inventory: Ajuntament de Barcelona / Open Data BCN · CC BY 4.0.\nhttps://opendata-ajuntament.barcelona.cat/data/en/dataset/arbrat-viari\nTree coordinates retained; appearance estimated.\nLamp positions: Ajuntament de Barcelona / CartoBCN, CC BY 3.0 ES.\nSource updated 2025-12-13; retrieved 2026-09-27. ENE_06_PT survey layer.\nhttps://creativecommons.org/licenses/by/3.0/es/\nCoordinates transformed; lamp heights, shapes and light output illustrative.\nMap geometry and park-tree records © OpenStreetMap contributors, ODbL 1.0.\nhttps://www.openstreetmap.org/copyright\nData snapshot: " + str(District.DATA.metadata.retrieved_at) + "\nSource and adapted database are distributed in data/.\nTerrain: ICGC MET5, CC BY 4.0; resampled from 5 m to 6 m.\nhttps://www.icgc.cat\nBare-earth grades; bridge decks and tunnels not reconstructed.\nCoastline: OpenStreetMap; sea and terrain colors illustrative.\nBuilding façades and untagged dimensions are estimated.\nLandmark facts: sagradafamilia.org/en/history-of-the-temple\n\nGODOT ENGINE\n" + Engine.get_license_text() + "\n\nTHIRD-PARTY COMPONENTS\n" + JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\nLICENSE TEXTS\n" + JSON.stringify(Engine.get_license_info(), "  ")
	if not BuildingAssets.active_credits.is_empty():
		text.text += "\n\nIMPORTED BUILDING ASSETS\n" + "\n\n".join(BuildingAssets.active_credits)
	credits.add_child(text)

func build_places() -> void:
	places_overlay = overlay()
	var column := centered_column(places_overlay)
	column.custom_minimum_size.x = 850
	column.add_child(label("Explore the recorded city", 30))
	column.add_child(label("Offline OSM snapshot · " + str(District.DATA.metadata.retrieved_at).left(10) + " · Records may be older", 14, Color("e8c281")))
	place_search = LineEdit.new()
	place_search.placeholder_text = "Search shop, café, street or house number"
	place_search.custom_minimum_size.y = 44
	search_timer = Timer.new()
	search_timer.one_shot = true
	search_timer.wait_time = 0.25
	add_child(search_timer)
	search_timer.timeout.connect(filter_places)
	place_search.text_changed.connect(func(_text: String):
		route_place_button.disabled = true
		start_place_button.disabled = true
		search_timer.start())
	place_search.text_submitted.connect(func(_text: String): filter_places())
	column.add_child(place_search)
	places_list = ItemList.new()
	places_list.custom_minimum_size = Vector2(850, 180)
	places_list.add_theme_font_size_override("font_size", 17)
	places_list.item_selected.connect(select_place)
	column.add_child(places_list)
	places_info = RichTextLabel.new()
	places_info.custom_minimum_size = Vector2(850, 120)
	places_info.add_theme_font_size_override("normal_font_size", 16)
	column.add_child(places_info)
	route_place_button = button("Drive to the nearest mapped road", func():
		if not selected_place.is_empty():
			places_overlay.hide()
			place_requested.emit(selected_place))
	column.add_child(route_place_button)
	start_place_button = button("Start at this address / place", func():
		if not selected_place.is_empty(): start_requested.emit(District.vector(selected_place.point)))
	column.add_child(start_place_button)
	column.add_child(button("Back to map", open_map))

func open_places() -> void:
	if not car.paused:
		pause_requested.emit()
	pause_overlay.hide()
	map_overlay.hide()
	places_overlay.show()
	filter_places()

func filter_places() -> void:
	filtered_places.clear()
	places_list.clear()
	selected_place = {}
	route_place_button.disabled = true
	places_info.text = "Select a record. Missing addresses are never inferred. OSM edit dates are not business verification dates."
	start_place_button.disabled = true
	search_timer.stop()
	filtered_places = address_lookup.search(place_search.text)
	for record in filtered_places:
		var text := "%s  ·  %s %s" % [record.name, record.street, record.number]
		if record.category.begins_with("Recorded address"): text = record.name + "  ·  " + record.category
		if record.category.begins_with("Metro") or record.category == "Bus stop":
			text = "%s · %s %s" % [record.name, record.category, record.get("ref", "")]
		if record.get("suggested", false): text = "Suggested: " + text
		places_list.add_item(text)
	if filtered_places.is_empty(): places_info.text = "No recorded match. Try the street name without a number, or choose a starting point on the city map."
	elif filtered_places.size() >= 300: places_info.text = "Showing the first 300 matches. Add a street name or house number to narrow the search."

func select_place(index: int) -> void:
	selected_place = filtered_places[index]
	var p := selected_place
	var address := "%s %s" % [p.street, p.number] if not p.street.is_empty() and not p.number.is_empty() else "Full street address not recorded"
	places_info.text = "%s · %s\n%s\nOSM %s · edited %s\nSurvey/check date: %s · Appearance is illustrative" % [p.name, p.category, address, p.id, p.timestamp.left(10), p.check_date if not p.check_date.is_empty() else "not recorded"]
	route_place_button.disabled = false
	start_place_button.disabled = false
	places_info.text += "\nStart here places your car on the nearest drivable road. Address ranges retain the source location."

func build_city_map() -> void:
	map_overlay = overlay()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	map_overlay.add_child(column)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	actions.add_child(label("Barcelona", 23))
	actions.add_child(button("−", func(): city_map.change_zoom(1 / 1.5)))
	actions.add_child(button("+", func(): city_map.change_zoom(1.5)))
	actions.add_child(button("Whole city", func(): city_map.show_city()))
	actions.add_child(button("My car", func(): city_map.show_car()))
	actions.add_child(button("Close", close_map))
	var tools := HBoxContainer.new()
	column.add_child(tools)
	tools.add_child(button("Search places & addresses", open_places))
	map_orientation_button = button("Heading up", map_orientation_requested.emit)
	tools.add_child(map_orientation_button)
	route_label = label("", 15)
	route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(route_label)
	city_map = CityMap.new()
	city_map.car = car
	city_map.navigation = navigation
	city_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	city_map.custom_minimum_size = Vector2(0, 250)
	column.add_child(city_map)
	city_map.point_selected.connect(func(point: Vector3):
		map_target = point
		var nearest := District.nearest_segment(point)
		map_info.text = "%s · start on the road, %d m from selected point" % [nearest.road.name, roundi(nearest.distance)]
		map_start_button.disabled = false)
	map_info = label("Tap a point, then Start here. Drag to pan; use + / − or the mouse wheel to zoom.", 16)
	map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(map_info)
	map_start_button = button("Start here", func():
		if map_target.is_finite(): start_requested.emit(map_target))
	map_start_button.disabled = true
	column.add_child(map_start_button)
	column.add_child(label("White: car  /  Gold ring: starting road", 12))

func open_map() -> void:
	if not car.paused: pause_requested.emit()
	pause_overlay.hide()
	places_overlay.hide()
	map_target = Vector3.INF
	map_start_button.disabled = true
	map_info.text = "Tap a point, then Start here. Drag to pan; use + / − or the mouse wheel to zoom."
	map_overlay.show()
	city_map.selected = Vector3.INF
	city_map.show_city()

func close_map() -> void:
	map_overlay.hide()
	if car.paused: pause_requested.emit()
