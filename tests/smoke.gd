extends SceneTree

var failures := 0
var checks := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save.path = "user://smoke_map_journey.json"
	if FileAccess.file_exists(game.save.path):
		DirAccess.remove_absolute(game.save.path)
	root.add_child(game)
	Engine.max_fps = 0
	await frames(3)
	var onscreen := true
	for pedal in game.hud.touch_buttons.values():
		onscreen = onscreen and root.get_visible_rect().encloses(pedal.get_global_rect())
	check(onscreen and root.get_visible_rect().encloses(game.hud.map.get_global_rect()), "Touch controls and mapped minimap fit inside viewport")
	var car: TouringCar = game.car
	game.controls.injected = true
	car.recover(District.START, District.START_HEADING)
	game.controls.throttle = 1
	await frames(100)
	check(car.speed > 10 and car.position.distance_to(District.START) > 8, "Acceleration advances along a real road")
	game.controls.throttle = 0
	game.controls.brake = 1
	await frames(45)
	check(absf(car.speed) < 3, "Braking brings forward motion to a stop")
	await frames(90)
	check(car.speed < -2, "Brake held at rest engages reverse")
	game.controls.brake = 0
	car.recover(District.START, District.START_HEADING)
	game.controls.throttle = 1
	game.controls.steering = 1
	await frames(35)
	check(car.rotation.y < District.START_HEADING - 0.05, "Right steering changes heading correctly")
	car.recover(District.START, District.START_HEADING)
	game.controls.steering = -1
	await frames(35)
	check(car.rotation.y > District.START_HEADING + 0.05, "Left steering changes heading correctly")
	game.controls.steering = 0
	game.controls.throttle = 0
	car.recover(District.START, District.START_HEADING)
	await frames(5)
	var start := car.position + Vector3.UP
	var side := car.global_basis.x
	var query := PhysicsRayQueryParameters3D.create(start, start + side * 45, 1)
	var hit := car.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty(), "Imported building wall has a collision surface")
	if not hit.is_empty():
		car.position = hit.position + hit.normal * 5
		car.position.y = 0.55
		car.rotation.y = atan2(hit.normal.x, hit.normal.z)
		game.controls.throttle = 1
		var contact := false
		for i in 120:
			await physics_frame
			contact = contact or car.collided
		check(contact and (car.position - hit.position).dot(hit.normal) > 0, "Driving into a mapped façade is stopped by collision")
		game.controls.throttle = 0
		car.speed = 0
		car.velocity = Vector3.ZERO
		car.position = hit.position + hit.normal * 2
		car.position.y = 0.55
		car.rotation.y = atan2(-hit.normal.x, -hit.normal.z)
		game.camera.reset()
		check((game.camera.position - hit.position).dot(hit.normal) > 0 and game.camera.position.distance_to(car.position) < 9, "Chase camera shortens against mapped façade")
	car.position = Vector3(District.BOUNDS.end.x - 8, 0.55, District.BOUNDS.get_center().y)
	car.rotation.y = -PI / 2
	game.controls.throttle = 1
	await frames(150)
	check(car.position.x < District.BOUNDS.end.x, "Snapshot boundary prevents escape")
	game.controls.throttle = 0
	car.recover(District.START, District.START_HEADING)
	game.camera.reset()
	await frames(10)
	check(car.position.y > -1 and game.camera.position.is_finite(), "Ground and chase camera remain stable")
	var before := car.position
	game.toggle_pause()
	game.controls.throttle = 1
	await frames(20)
	check(car.position.distance_to(before) < 0.01, "Pause freezes driving")
	game.toggle_pause()
	game.controls.throttle = 0
	game.controls.injected = false
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await process_frame
	game.controls.sample()
	check(game.controls.throttle == 1, "Keyboard W accelerates")
	var release := key.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame
	game.hud.assign_touch(1, game.hud.touch_buttons.left.get_global_rect().get_center())
	game.hud.assign_touch(2, game.hud.touch_buttons.gas.get_global_rect().get_center())
	game.hud.sync_touches()
	game.controls.sample()
	check(game.controls.steering == -1 and game.controls.throttle == 1, "Two-finger steering and throttle coexist")
	game.hud.release_touches()
	game.controls.sample()
	check(game.controls.steering == 0 and game.controls.throttle == 0, "Release clears touch input")
	game.controls.injected = true
	game.select_destination()
	var path: PackedVector3Array = game.navigation.route(District.START).duplicate()
	check(game.navigation.reachable and path.size() > 1 and path[-1].distance_to(District.DESTINATION) < 0.1, "Directed mapped-road route reaches landmark")
	var on_roads := true
	for i in range(1, path.size()):
		on_roads = on_roads and District.nearest_segment(path[i - 1].lerp(path[i], 0.5)).distance < 0.1
	check(on_roads, "Navigation follows imported road segments rather than an invented grid")
	# Drive the full starter route using the actual car controller and physics.
	car.recover(District.START, District.START_HEADING)
	var waypoint := 1
	for i in 3000:
		if game.landmarks.discovered:
			break
		while waypoint < path.size() - 1 and car.position.distance_to(path[waypoint]) < 6:
			waypoint += 1
		var difference: Vector3 = path[waypoint] - car.position
		var desired := atan2(-difference.x, -difference.z)
		game.controls.steering = clampf(-wrapf(desired - car.rotation.y, -PI, PI) * 2, -1, 1)
		var arriving := car.position.distance_to(District.DESTINATION) < 13
		game.controls.throttle = 1 if not arriving and car.speed < 10 else 0
		game.controls.brake = 1 if arriving and car.speed > 0.3 else 0
		await physics_frame
	check(game.landmarks.discovered and game.hud.card_overlay.visible, "Complete physical drive from start reaches landmark and opens card")
	game.controls.clear()
	game.close_card()
	check(not game.is_paused, "Continue exploring resumes the loop")
	game.hud.open_places()
	game.hud.place_search.text = "Provença"
	game.hud.filter_places()
	check(game.hud.filtered_places.size() > 0 and game.is_paused, "Offline places browser searches real street names while paused")
	game.hud.select_place(0)
	check("edited" in game.hud.places_info.text and "Survey/check date" in game.hud.places_info.text, "Place details distinguish OSM edit date and survey date")
	var place: Dictionary = game.hud.selected_place
	var original_id: String = place.id
	game.hud.filter_places()
	check(place.get("id", "") == original_id, "Filtering places does not mutate the source record")
	game.route_to_place(place)
	check(game.navigation.destination_name == place.name and District.nearest_segment(game.navigation.destination).distance < 0.01, "Selected shop routes to a mapped road")
	game.hud.places_overlay.hide()
	game.toggle_sound()
	game.toggle_fps()
	game.persist()
	var restored := SaveStore.new()
	restored.path = game.save.path
	restored.load_journey()
	check("sagrada_familia" in restored.discovered and District.is_safe(restored.safe_position), "Save reload restores real-map safe position and discovery")
	check(restored.muted and restored.fps == 60, "Sound and frame-cap settings persist")
	car.position = Vector3(9999, -50, 9999)
	game.recover()
	check(District.is_safe(car.position) and car.speed == 0, "Recovery returns invalid position to a mapped road")
	var broken := FileAccess.open(game.save.path, FileAccess.WRITE)
	broken.store_string(JSON.stringify({"version":1,"district":District.ID,"position":[99999,0,99999],"heading":"bad","discovered":3}))
	broken.close()
	var fallback := SaveStore.new()
	fallback.path = game.save.path
	fallback.load_journey()
	check(fallback.safe_position == District.START and fallback.heading == District.START_HEADING, "Malformed save falls back to correct map spawn")
	DirAccess.remove_absolute(game.save.path)
	game.queue_free()
	await process_frame
	WorldBuilder.materials.clear()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
