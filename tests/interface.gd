extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		push_error(message)
		failures += 1

func text_exists(node: Node, value: String) -> bool:
	if node is Label or node is Button or node is RichTextLabel:
		if value in node.text:
			return true
	for child in node.get_children():
		if text_exists(child, value):
			return true
	return false

func visible_text_contains(node: Node, value: String) -> bool:
	if node is Control and not node.is_visible_in_tree():
		return false
	if (node is Label or node is Button or node is RichTextLabel) and value in node.text:
		return true
	for child in node.get_children():
		if visible_text_contains(child, value):
			return true
	return false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save.path = "user://interface-test.json"
	root.add_child(game)
	for i in 4:
		await process_frame
	check(game.is_paused and game.onboarding.visible and not game.hud.root.visible, "Application opens on onboarding instead of driving")
	check(text_exists(game.onboarding.content, "City Explorer") and text_exists(game.onboarding.content, "Explore cities from the driver's seat."), "Home has concise product messaging")
	check(text_exists(game.onboarding.content, "Explore") and text_exists(game.onboarding.content, "Game Mode"), "Home exposes Explore and a coming-soon Game Mode")
	game.onboarding.show_city()
	check(game.session.screen == AppSession.Screen.CITY and text_exists(game.onboarding.content, "Barcelona"), "Explore continues to reusable city selection")
	game.onboarding._select_city(AppCatalog.city("barcelona"))
	check(game.session.screen == AppSession.Screen.LOCATION and game.onboarding.search_field != null, "City selection continues to location search")
	game.onboarding.search_field.text = "Sagrada Família"
	game.onboarding._search_now()
	check(not game.onboarding.results.is_empty(), "Location screen uses real offline records when Google is unconfigured")
	game.onboarding._choose_place(game.onboarding.results[0])
	check(game.session.screen == AppSession.Screen.VEHICLE and game.session.selected_point.is_finite(), "Place selection resolves coordinates before vehicle selection")
	check(text_exists(game.onboarding.content, "City Touring Car") and text_exists(game.onboarding.content, "Start exploring"), "Vehicle screen presents the current car through reusable catalog data")
	game.onboarding._start_exploring()
	await process_frame
	game.hud.refresh(false, false, 30)
	check(not game.is_paused and not game.onboarding.visible and game.hud.root.visible, "Start exploring enters the existing driving experience")
	check(game.hud.street_label.is_visible_in_tree() and not game.hud.street_label.text.is_empty(), "Current street remains visible")
	check(game.hud.speed_label.get_theme_font_size("font_size") == 52, "Speed remains prominent and legible")
	check(not visible_text_contains(game.hud.chrome, "WASD") and not visible_text_contains(game.hud.chrome, "©") and not visible_text_contains(game.hud.chrome, "Mapped streets"), "Driving chrome omits instructions, legal copy and technical labels")
	game.toggle_pause()
	check(game.hud.pause_overlay.visible and text_exists(game.hud.pause_overlay, "Choose new location") and text_exists(game.hud.pause_overlay, "Exit to Home"), "Pause offers clear journey actions")
	game.hud.open_settings()
	check(game.hud.settings_overlay.visible and text_exists(game.hud.settings_overlay, "APPEARANCE") and text_exists(game.hud.settings_overlay, "Credits & Licences"), "Settings groups appearance, sound, performance, controls and legal")
	game.hud.open_credits()
	check(visible_text_contains(game.hud.credits_overlay, "OpenStreetMap") and visible_text_contains(game.hud.credits_overlay, "ICGC") and visible_text_contains(game.hud.credits_overlay, "CartoBCN"), "Required data attribution remains available in Legal")
	game.change_theme("light")
	check(game.save.theme == "light" and game.hud.theme_mode == "light" and game.onboarding.theme_mode == "light", "Appearance selection applies and persists across interfaces")
	if "--capture" in OS.get_cmdline_user_args():
		game.exit_to_home()
		for scene in ["home", "city", "location", "vehicle", "drive", "pause", "settings"]:
			match scene:
				"city": game.onboarding.show_city()
				"location": game.onboarding.show_location()
				"vehicle":
					game.session.selected_point = District.START
					game.onboarding.show_vehicle()
				"drive":
					game.onboarding.hide()
					game.onboarding.active = false
					game.begin_exploration(game.session.selected_city, {"name":"Test"}, game.session.selected_vehicle, District.START)
				"pause": game.toggle_pause()
				"settings": game.hud.open_settings()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/city-explorer-%s.png" % scene)
	game.free()
	await process_frame
	DirAccess.remove_absolute("user://interface-test.json")
	print("RESULT: interface checks, %d failures" % failures)
	quit(1 if failures else 0)
