extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message)
	else:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save.path = "user://interface-test.json"
	root.add_child(game)
	for i in 3: await process_frame
	var hud: DrivingHUD = game.hud
	hud.refresh(false, false, 30)
	check(hud.street_label.is_visible_in_tree() and not hud.street_label.text.is_empty(), "Current street remains visible")
	check(not hud.route_label.is_visible_in_tree() and not hud.map_orientation_button.is_visible_in_tree(), "Navigation details stay out of the driving view")
	check(hud.speed_label.get_theme_font_size("font_size") == 56, "Speed is larger and legible")
	var forbidden := false
	for node in hud.root.get_children():
		if node is Label and node.is_visible_in_tree():
			for text in ["BRISA", "WASD", "©", "Mapped streets"]:
				forbidden = forbidden or text in node.text
	check(not forbidden, "Driving HUD omits title, attribution and keyboard instructions")
	hud.open_map()
	check(hud.map_overlay.visible and game.is_paused and hud.map_orientation_button.is_visible_in_tree(), "Expanded map contains orientation controls")
	hud.open_places()
	check(hud.places_overlay.visible and not hud.map_overlay.visible and game.is_paused, "Map search opens while driving stays paused")
	hud.place_search.text = "Gretel Ammann"
	hud.filter_places()
	check(not hud.filtered_places.is_empty(), "Address search remains available inside map flow")
	hud.open_map()
	check(hud.map_overlay.visible and not hud.places_overlay.visible and game.is_paused, "Back from search returns to map")
	hud.close_map()
	check(not game.is_paused, "Closing map resumes driving")
	if "--capture" in OS.get_cmdline_user_args():
		game.car.paused = true
		game.world.daylight.set_process(false)
		for scene in ["drive", "pause", "map", "night"]:
			game.world.daylight.update_at(Time.get_unix_time_from_datetime_string("2026-09-27T12:00:00" if scene != "night" else "2026-09-27T00:00:00"))
			hud.pause_overlay.visible = scene == "pause"
			hud.map_overlay.visible = scene == "map"
			game.car.headlights.visible = scene == "night"
			game.world.street_lighting.update_lights()
			for i in 6: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/city-explorer-%s.png" % scene)
	game.free()
	await process_frame
	print("RESULT: interface checks, %d failures" % failures)
	quit(1 if failures else 0)
