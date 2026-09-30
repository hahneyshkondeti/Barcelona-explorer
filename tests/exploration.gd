extends SceneTree
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: " + message)
	else:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var lookup := AddressSearch.new()
	var records := lookup.search("Carrer Gretel Ammann Marinez 12")
	check(not records.is_empty(), "User's address query tolerates accents, omitted de and a spelling typo")
	if records.is_empty(): quit(1); return
	var record: Dictionary = records[0]
	check(record.street == "Carrer de Gretel Ammann Martínez" and record.number == "16-12", "Search preserves the supplied address range rather than inventing a door")
	check(record.get("suggested", false), "Spelling suggestions are labeled")
	check(lookup.search("Carrer Gretel Ammann Martinez 99999").is_empty(), "Unrecorded house number is not fabricated")
	check(lookup.search("Gretel Ammann Martínez 12")[0].get("suggested", false) == false, "Accent-insensitive exact match ranks ahead of spelling suggestions")
	var game = load("res://scenes/main.tscn").instantiate()
	game.save.path = "user://exploration_test.json"
	if FileAccess.file_exists(game.save.path): DirAccess.remove_absolute(game.save.path)
	root.add_child(game)
	game.onboarding.hide()
	game.onboarding.active = false
	game.begin_exploration(game.session.selected_city, {"name":"Test start"}, game.session.selected_vehicle, District.START)
	var original_heading: float = game.car.rotation.y
	for heading in [0.0, PI * 0.5, PI, -PI * 0.5]:
		game.car.rotation.y = heading
		game.hud.map.north_locked = false
		var ahead: Vector3 = game.car.position - game.car.basis.z * 30
		var projected: Vector2 = game.hud.map.map_point(ahead) - game.hud.map.size * 0.5
		game.hud.map.north_locked = true
		var north: Vector2 = game.hud.map.map_point(game.car.position + Vector3(0, 0, -30)) - game.hud.map.size * 0.5
		check(absf(projected.x) < 0.01 and projected.y < 0 and absf(north.x) < 0.01 and north.y < 0, "Heading-up and north-up transforms agree at heading %.2f" % heading)
	game.car.rotation.y = original_heading
	game.hud.map.north_locked = false
	game.hud.map_orientation_button.pressed.emit()
	check(game.hud.map.north_locked and game.save.north_locked and not game.is_paused, "Minimap lock toggles without pausing driving")
	var settings := SaveStore.new()
	settings.path = game.save.path
	settings.load_journey()
	check(settings.north_locked, "North-lock preference survives save and reload")
	game.hud.map_orientation_button.pressed.emit()
	check(not game.hud.map.north_locked, "Tapping the map mode again restores heading-following")
	var map := CityMap.new()
	map.car = game.car
	map.navigation = game.navigation
	map.size = Vector2(800, 500)
	root.add_child(map)
	await process_frame
	var point := District.vector(record.point)
	check(map.world_point(map.map_point(point)).distance_to(point) < 0.02, "Map coordinates round-trip without aspect distortion")
	var anchor := map.size * Vector2(0.65, 0.4)
	var before := map.world_point(anchor)
	map.change_zoom(2, anchor)
	check(map.world_point(anchor).distance_to(before) < 0.02, "Zoom stays anchored at the pointer")
	map.choose(map.map_point(point))
	check(map.selected.distance_to(District.nearest_road(point)) < 0.02, "Map selection previews the actual drivable starting point")
	var previous: Vector3 = map.selected
	map.begin_drag(map.size * 0.5)
	map.move_drag(map.size * 0.5 + Vector2(40, 20))
	map.end_drag(map.size * 0.5 + Vector2(40, 20))
	check(map.selected == previous, "Dragging pans without accidentally choosing a start")
	var selected_point: Vector3 = map.selected
	map.free()
	game.start_at(selected_point)
	check(not game.is_paused and District.is_safe(game.car.position), "Start coordinates snap to a safe road")
	var saved := SaveStore.new()
	saved.path = game.save.path
	saved.load_journey()
	check(saved.safe_position.distance_to(game.car.position) < 0.02, "Chosen starting point persists locally")
	game.choose_new_location()
	game.onboarding.search_field.text = "Carrer Gretel Ammann Marinez 12"
	game.onboarding._search_now()
	game.onboarding._choose_place(game.onboarding.results[0])
	check(game.session.screen == AppSession.Screen.VEHICLE and game.session.selected_point.distance_to(point) < 0.02, "Address action resolves the matching map coordinate")
	game.onboarding._start_exploring()
	check(not game.onboarding.visible and game.car.position.distance_to(District.nearest_road(point)) < 0.02, "Start exploring launches on the matching safe road")
	var old: Vector3 = game.car.position
	game.start_at(Vector3.INF)
	check(game.car.position == old, "Invalid launch coordinates cannot move the car")
	var wrapped := WorldBuilder.wrap_street_name("Carrer de Gretel Ammann Martínez")
	check("\n" in wrapped and wrapped.replace("\n", " ") == "Carrer de Gretel Ammann Martínez", "Long street labels wrap without dropping any part of the name")
	var covered := true
	for chunk in game.world.loaded_chunks.values():
		var names := {}
		for sign in chunk.street_signs: names[sign.get_meta("street_name", sign.text)] = true
		for road in chunk.features.roads:
			if road.name != "Unnamed mapped way" and not str(road.name).strip_edges().is_empty():
				covered = covered and names.has(road.name)
	check(covered, "Every named street in loaded tiles has a label, including short segments")
	game.world.refresh_street_labels()
	var visible_names := {}
	var unique := true
	for chunk in game.world.loaded_chunks.values():
		for sign in chunk.street_signs:
			if sign.visible:
				unique = unique and not visible_names.has(sign.text)
				visible_names[sign.get_meta("street_name", sign.text)] = true
	check(unique, "Floating labels suppress same-street repeats across tile boundaries")
	# Capture the actual interfaces when run with -- --capture.
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/street-labels.png")
		game.choose_new_location()
		game.onboarding.search_field.text = "Gretel Ammann"
		game.onboarding._search_now()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/address-start.png")
	game.world.stream_at(game.car.position, true)
	await process_frame
	await process_frame
	game.free()
	DirAccess.remove_absolute("user://exploration_test.json")
	print("RESULT: %d exploration checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
