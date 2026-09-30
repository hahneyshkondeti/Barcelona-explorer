extends Node3D

var world: WorldBuilder
var car: TouringCar
var camera: ChaseCamera
var controls: DriveInput
var hud: DrivingHUD
var landmarks: Landmarks
var audio: EngineAudio
var navigation := RoadNavigation.new()
var save := SaveStore.new()
var session := AppSession.new()
var onboarding: OnboardingFlow
var save_timer := 0.0
var route_timer := 0.0
var is_paused := false
var hud_timer := 0.0

func _ready() -> void:
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		get_viewport().use_taa = true
	save.load_journey()
	session.theme = save.theme
	session.select_city(save.selected_city)
	session.select_vehicle(save.selected_vehicle)
	Engine.max_fps = save.fps
	world = WorldBuilder.new()
	add_child(world)
	controls = DriveInput.new()
	add_child(controls)
	car = TouringCar.new()
	car.controls = controls
	add_child(car)
	car.recover(save.safe_position, save.heading)
	world.stream_at(car.global_position, true)
	camera = ChaseCamera.new()
	camera.target = car
	add_child(camera)
	camera.reset()
	landmarks = Landmarks.new()
	landmarks.car = car
	landmarks.discovered = "sagrada_familia" in save.discovered
	landmarks.arrived.connect(on_arrival)
	add_child(landmarks)
	audio = EngineAudio.new()
	audio.car = car
	audio.muted = save.muted
	add_child(audio)
	hud = DrivingHUD.new()
	hud.controls = controls
	hud.car = car
	hud.navigation = navigation
	add_child(hud)
	hud.pause_requested.connect(toggle_pause)
	hud.recover_requested.connect(recover)
	hud.sound_requested.connect(toggle_sound)
	hud.fps_requested.connect(toggle_fps)
	hud.restart_requested.connect(restart_selected_location)
	hud.choose_location_requested.connect(choose_new_location)
	hud.choose_vehicle_requested.connect(choose_new_vehicle)
	hud.home_requested.connect(exit_to_home)
	hud.theme_requested.connect(change_theme)
	hud.map.north_locked = save.north_locked
	hud.map_orientation_requested.connect(toggle_map_orientation)
	hud.continue_requested.connect(close_card)
	hud.apply_theme(session.theme)
	hud.set_exploring_visible(false)
	onboarding = OnboardingFlow.new()
	onboarding.configure(session)
	add_child(onboarding)
	onboarding.exploration_requested.connect(begin_exploration)
	onboarding.preference_changed.connect(persist_preferences)
	set_paused(true)
	update_route()

func _process(delta: float) -> void:
	world.stream_at(car.global_position)
	hud_timer += delta
	if hud_timer >= 0.1:
		hud.refresh(landmarks.discovered, save.muted, save.fps)
		hud_timer = 0.0
	if is_paused:
		return
	route_timer += delta
	save_timer += delta
	if route_timer > 2.0:
		update_route()
		route_timer = 0
	if save_timer > 3:
		persist()
		save_timer = 0
	if not car.global_position.is_finite() or not District.in_bounds(car.position, 5):
		recover()
		return
	var ground_height := TerrainData.height(car.position.x, car.position.z)
	if car.position.y < ground_height - 4 or ground_height < -0.5:
		recover()

func _unhandled_input(event: InputEvent) -> void:
	if onboarding != null and onboarding.active:
		return
	if event.is_action_pressed("pause_game"):
		if hud.card_overlay.visible:
			close_card()
		else:
			toggle_pause()
	elif event.is_action_pressed("recover_car"):
		recover()
	elif event.is_action_pressed("reset_camera"):
		camera.reset()

func update_route() -> void:
	world.update_route(navigation.route(car.global_position))

func set_paused(value: bool) -> void:
	is_paused = value
	car.paused = value
	controls.enabled = not value
	hud.release_touches()
	if value:
		persist()

func toggle_pause() -> void:
	if onboarding != null and onboarding.active:
		return
	set_paused(not is_paused)
	if is_paused:
		session.screen = AppSession.Screen.PAUSED
		hud.open_pause()
	else:
		session.screen = AppSession.Screen.EXPLORING
		hud.close_all_overlays()

func recover() -> void:
	car.recover(save.safe_position, save.heading)
	world.stream_at(car.global_position, true)
	camera.reset()
	hud.close_all_overlays()
	set_paused(false)
	session.screen = AppSession.Screen.EXPLORING
	update_route()

func select_destination() -> void:
	navigation.active = true
	navigation.destination = District.DESTINATION
	navigation.destination_name = District.TITLE
	update_route()
	if landmarks.discovered and car.global_position.distance_to(District.DESTINATION) < 16 and absf(car.speed) < 2:
		on_arrival()

func on_arrival() -> void:
	if not "sagrada_familia" in save.discovered:
		save.discovered.append("sagrada_familia")
	navigation.active = false
	update_route()
	set_paused(true)
	hud.card_overlay.show()

func close_card() -> void:
	hud.card_overlay.hide()
	landmarks.dismiss()
	set_paused(false)
	session.screen = AppSession.Screen.EXPLORING

func toggle_sound() -> void:
	save.muted = not save.muted
	audio.muted = save.muted
	persist()

func toggle_map_orientation() -> void:
	save.north_locked = not save.north_locked
	hud.map.north_locked = save.north_locked
	hud.refresh(landmarks.discovered, save.muted, save.fps)
	persist()

func toggle_fps() -> void:
	save.fps = 60 if save.fps == 30 else 30
	Engine.max_fps = save.fps
	persist()

func persist() -> void:
	if District.is_safe(car.global_position) and not car.collided:
		save.safe_position = District.nearest_road(car.global_position)
		save.heading = car.rotation.y
	if not save.write_journey():
		hud.notice.text = save.last_error

func persist_preferences() -> void:
	save.theme = session.theme
	save.selected_city = session.selected_city.id
	save.selected_vehicle = session.selected_vehicle.id
	persist()

func _notification(what: int) -> void:
	if not is_instance_valid(hud):
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if onboarding == null or not onboarding.active:
			set_paused(true)
			if not hud.card_overlay.visible:
				hud.open_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		persist()

func route_to_place(place: Dictionary) -> void:
	navigation.destination = District.nearest_road(District.vector(place.point))
	navigation.destination_name = place.name
	navigation.active = true
	set_paused(false)
	hud.pause_overlay.hide()
	update_route()

func explore_area(index: int) -> void:
	if index < 0 or index >= District.AREAS.size(): return
	var area: Dictionary = District.AREAS[index]
	var target := BuildingAssets.anchor_position(area.lonlat[0], area.lonlat[1], 0.55)
	start_at(target)

func start_at(point: Vector3) -> bool:
	if not District.in_bounds(point, -3):
		return false
	var target := District.nearest_road(point)
	if not District.is_safe(target):
		return false
	car.recover(target, District.heading_at(target))
	world.stream_at(car.global_position, true)
	camera.reset()
	navigation.active = false
	update_route()
	hud.close_all_overlays()
	set_paused(false)
	session.screen = AppSession.Screen.EXPLORING
	persist()
	return true

func begin_exploration(city: Dictionary, place: Dictionary, vehicle: Dictionary, point: Vector3) -> void:
	session.selected_city = city
	session.selected_place = place
	session.selected_vehicle = vehicle
	session.selected_point = point
	hud.set_city_name(city.name)
	hud.set_exploring_visible(true)
	if not start_at(point):
		hud.set_exploring_visible(false)
		onboarding.show_error("Unable to start here. Choose another place in the supported city area.")
		return
	persist_preferences()

func restart_selected_location() -> void:
	if session.selected_point.is_finite():
		start_at(session.selected_point)
	else:
		recover()

func choose_new_location() -> void:
	set_paused(true)
	hud.close_all_overlays()
	hud.set_exploring_visible(false)
	onboarding.show_location()

func choose_new_vehicle() -> void:
	set_paused(true)
	hud.close_all_overlays()
	hud.set_exploring_visible(false)
	if session.selected_point.is_finite():
		onboarding.show_vehicle()
	else:
		onboarding.show_location()

func exit_to_home() -> void:
	set_paused(true)
	hud.close_all_overlays()
	hud.set_exploring_visible(false)
	onboarding.show_home()

func change_theme(mode: String) -> void:
	if mode not in ["dark", "light", "system"]:
		return
	session.theme = mode
	save.theme = mode
	hud.apply_theme(mode)
	onboarding.apply_theme(mode)
	persist_preferences()
