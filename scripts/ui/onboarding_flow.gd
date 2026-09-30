class_name OnboardingFlow
extends CanvasLayer

signal exploration_requested(city: Dictionary, place: Dictionary, vehicle: Dictionary, point: Vector3)
signal preference_changed

var session: AppSession
var root: ColorRect
var panel: PanelContainer
var content: VBoxContainer
var search_field: LineEdit
var results_box: VBoxContainer
var status_label: Label
var search_timer: Timer
var place_service: PlaceSearchService
var results: Array = []
var theme_mode := "dark"
var active := true

func _ready() -> void:
	layer = 20
	place_service = PlaceSearchService.new()
	add_child(place_service)
	place_service.loading_changed.connect(_search_loading)
	place_service.results_ready.connect(_search_results)
	place_service.search_failed.connect(_search_failed)
	place_service.place_resolved.connect(_place_resolved)
	search_timer = Timer.new()
	search_timer.one_shot = true
	search_timer.wait_time = 0.28
	search_timer.timeout.connect(_search_now)
	add_child(search_timer)
	root = ColorRect.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.color = UIDesignSystem.colors(theme_mode).background
	add_child(root)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	root.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	apply_theme(theme_mode)
	show_home(false)

func configure(value: AppSession) -> void:
	session = value
	theme_mode = value.theme
	if is_node_ready():
		apply_theme(theme_mode)

func apply_theme(mode: String) -> void:
	theme_mode = mode
	if root == null:
		return
	var c := UIDesignSystem.colors(mode)
	root.color = c.background
	root.theme = UIDesignSystem.theme(mode)
	panel.add_theme_stylebox_override("panel", UIDesignSystem.box(c.surface, 20))
	_restyle_primary_buttons()

func _apply_layout() -> void:
	if panel == null:
		return
	panel.custom_minimum_size.x = clampf(get_viewport().get_visible_rect().size.x - 48.0, 300.0, 660.0)

func _clear() -> void:
	for child in content.get_children():
		child.hide()
		child.queue_free()

func _heading(title: String, subtitle: String = "") -> void:
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title_label)
	if not subtitle.is_empty():
		var secondary := Label.new()
		secondary.text = subtitle
		secondary.add_theme_font_size_override("font_size", 17)
		secondary.add_theme_color_override("font_color", UIDesignSystem.colors(theme_mode).secondary)
		secondary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(secondary)
	_spacer(16)

func _spacer(height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	content.add_child(spacer)

func _button(text: String, action: Callable, primary := false) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 54
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.pressed.connect(action)
	result.set_meta("primary", primary)
	content.add_child(result)
	if primary:
		UIDesignSystem.primary(result, theme_mode)
	return result

func _back(action: Callable) -> void:
	var result := _button("‹  Back", action)
	result.custom_minimum_size.y = 42
	result.flat = true
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _transition() -> void:
	content.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(content, "modulate:a", 1.0, 0.2)
	_restyle_primary_buttons()

func _restyle_primary_buttons() -> void:
	if content == null:
		return
	for child in content.get_children():
		if child is Button and child.get_meta("primary", false):
			UIDesignSystem.primary(child, theme_mode)

func show_home(animate := true) -> void:
	active = true
	show()
	if session != null:
		session.screen = AppSession.Screen.HOME
	_clear()
	_heading("City Explorer", "Explore cities from the driver's seat.")
	_button("Explore", show_city, true)
	var game := _button("Game Mode\nComing soon", _game_mode_notice)
	game.add_theme_color_override("font_color", UIDesignSystem.colors(theme_mode).secondary)
	if animate:
		_transition()

func _game_mode_notice() -> void:
	var label := Label.new()
	label.text = "Game Mode is coming soon."
	label.add_theme_color_override("font_color", UIDesignSystem.colors(theme_mode).secondary)
	content.add_child(label)
	var tween := create_tween()
	label.modulate.a = 0
	tween.tween_property(label, "modulate:a", 1.0, 0.18)

func show_city() -> void:
	active = true
	show()
	if session != null:
		session.screen = AppSession.Screen.CITY
	_clear()
	_back(show_home)
	_heading("Choose a city", "More cities will join the collection over time.")
	for city in AppCatalog.cities():
		var item := _button("%s\n%s" % [city.name, city.country], func(): _select_city(city))
		item.disabled = not city.supported
	_transition()

func _select_city(city: Dictionary) -> void:
	session.selected_city = city
	preference_changed.emit()
	show_location()

func show_location() -> void:
	active = true
	show()
	session.screen = AppSession.Screen.LOCATION
	_clear()
	_back(show_city)
	_heading("Where do you want to start?", "%s, %s" % [session.selected_city.name, session.selected_city.country])
	search_field = LineEdit.new()
	search_field.placeholder_text = "Search places or addresses…"
	search_field.custom_minimum_size.y = 54
	search_field.clear_button_enabled = true
	search_field.text_changed.connect(func(_value: String):
		status_label.text = ""
		search_timer.start())
	search_field.text_submitted.connect(func(_value: String): _search_now())
	content.add_child(search_field)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", UIDesignSystem.colors(theme_mode).secondary)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "Search by address, landmark, restaurant, hotel, shop or neighbourhood."
	content.add_child(status_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 260
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	results_box = VBoxContainer.new()
	results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_box.add_theme_constant_override("separation", 8)
	scroll.add_child(results_box)
	_transition()
	search_field.grab_focus()

func _search_now() -> void:
	if search_field == null:
		return
	var query := search_field.text.strip_edges()
	if query.length() < 2:
		_clear_results()
		status_label.text = "Enter at least two characters."
		return
	place_service.search(query, session.selected_city)

func _search_loading(loading: bool) -> void:
	if status_label != null:
		status_label.text = "Searching…" if loading else ""

func _clear_results() -> void:
	if results_box == null:
		return
	for child in results_box.get_children():
		child.hide()
		child.queue_free()

func _search_results(value: Array) -> void:
	results = value
	_clear_results()
	if results.is_empty():
		status_label.text = "No places found"
		return
	status_label.text = "" if place_service.has_google_key() else "Offline city records · connect a Google Places key for broader search"
	for place in results:
		var row := Button.new()
		row.text = "%s\n%s" % [place.get("name", "Place"), place.get("address", "Barcelona")]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 66
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.pressed.connect(func(): _choose_place(place))
		results_box.add_child(row)

func _search_failed(message: String) -> void:
	if status_label != null:
		status_label.text = message

func show_error(message: String) -> void:
	if session.screen != AppSession.Screen.LOCATION or status_label == null:
		show_location()
	status_label.text = message

func _choose_place(place: Dictionary) -> void:
	status_label.text = "Finding the nearest driveable road…"
	place_service.resolve(place)

func _place_resolved(place: Dictionary) -> void:
	var point := Vector3.INF
	if place.get("source", "") == "offline" and place.get("point", []) is Array and place.point.size() >= 2:
		point = District.vector(place.point)
	elif place.has("longitude") and place.has("latitude"):
		point = BuildingAssets.anchor_position(float(place.longitude), float(place.latitude), 0.55)
	if not point.is_finite() or not District.in_bounds(point):
		status_label.text = "Location is outside the supported map area."
		return
	session.selected_place = place
	session.selected_point = point
	show_vehicle()

func show_vehicle() -> void:
	active = true
	show()
	session.screen = AppSession.Screen.VEHICLE
	_clear()
	_back(show_location)
	_heading("Choose your car", "Designed for relaxed city exploration.")
	content.add_child(_vehicle_preview())
	for vehicle in AppCatalog.vehicles():
		var selected: bool = vehicle.id == session.selected_vehicle.id
		var item := _button("%s%s\n%s" % [vehicle.display_name, "  ✓" if selected else "", vehicle.metadata.get("style", "")], func(): _select_vehicle(vehicle))
		item.disabled = not vehicle.available
	_spacer(6)
	_button("Start exploring", _start_exploring, true)
	_transition()

func _select_vehicle(vehicle: Dictionary) -> void:
	session.selected_vehicle = vehicle
	preference_changed.emit()
	show_vehicle()

func _vehicle_preview() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size.y = 210
	frame.add_theme_stylebox_override("panel", UIDesignSystem.box(UIDesignSystem.colors(theme_mode).surface_high, 16))
	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	frame.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 240)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport_container.add_child(viewport)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202023")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffffff")
	env.ambient_light_energy = 0.65
	environment.environment = env
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	viewport.add_child(light)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12, 12)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("29292d")
	floor_material.roughness = 0.92
	floor_mesh.material = floor_material
	floor.mesh = floor_mesh
	viewport.add_child(floor)
	var preview_controls := DriveInput.new()
	preview_controls.enabled = false
	viewport.add_child(preview_controls)
	var preview_car := TouringCar.new()
	preview_car.controls = preview_controls
	preview_car.paused = true
	preview_car.rotation.y = -0.65
	viewport.add_child(preview_car)
	var camera := Camera3D.new()
	camera.fov = 35.0
	camera.position = Vector3(4.5, 2.2, 5.5)
	camera.look_at_from_position(camera.position, Vector3(0, 0.7, 0))
	viewport.add_child(camera)
	return frame

func _start_exploring() -> void:
	if not session.selected_point.is_finite():
		show_location()
		return
	active = false
	hide()
	session.screen = AppSession.Screen.EXPLORING
	exploration_requested.emit(session.selected_city, session.selected_place, session.selected_vehicle, session.selected_point)
