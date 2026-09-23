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
var save_timer := 0.0
var route_timer := 0.0
var is_paused := false
var hud_timer := 0.0

func _ready() -> void:
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		get_viewport().use_taa = true
	save.load_journey()
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
	hud.place_requested.connect(route_to_place)
	hud.area_requested.connect(explore_area)
	hud.start_requested.connect(start_at)
	hud.pause_requested.connect(toggle_pause)
	hud.recover_requested.connect(recover)
	hud.camera_requested.connect(camera.reset)
	hud.destination_requested.connect(select_destination)
	hud.sound_requested.connect(toggle_sound)
	hud.fps_requested.connect(toggle_fps)
	hud.map.north_locked = save.north_locked
	hud.map_orientation_requested.connect(toggle_map_orientation)
	hud.continue_requested.connect(close_card)
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
	if not car.global_position.is_finite() or car.position.y < -4 or not District.in_bounds(car.position, 5):
		recover()

func _unhandled_input(event: InputEvent) -> void:
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
	set_paused(not is_paused)
	hud.pause_overlay.visible = is_paused
	if not is_paused:
		hud.places_overlay.hide()
		hud.map_overlay.hide()

func recover() -> void:
	car.recover(save.safe_position, save.heading)
	world.stream_at(car.global_position, true)
	camera.reset()
	hud.pause_overlay.hide()
	hud.card_overlay.hide()
	hud.places_overlay.hide()
	hud.map_overlay.hide()
	set_paused(false)
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

func _notification(what: int) -> void:
	if not is_instance_valid(hud):
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		set_paused(true)
		if not hud.card_overlay.visible:
			hud.pause_overlay.show()
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

func start_at(point: Vector3) -> void:
	if not District.in_bounds(point, -3): return
	var target := District.nearest_road(point)
	if not District.is_safe(target): return
	car.recover(target, District.heading_at(target))
	world.stream_at(car.global_position, true)
	camera.reset()
	navigation.active = false
	update_route()
	hud.pause_overlay.hide()
	hud.card_overlay.hide()
	hud.places_overlay.hide()
	hud.map_overlay.hide()
	set_paused(false)
	persist()
