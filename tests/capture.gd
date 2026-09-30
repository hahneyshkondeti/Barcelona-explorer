extends SceneTree

var game: Node3D
var suffix := "-mobile" if "--mobile-capture" in OS.get_cmdline_user_args() else ""

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save.path = "user://capture_journey.json"
	if FileAccess.file_exists(game.save.path):
		DirAccess.remove_absolute(game.save.path)
	root.add_child(game)
	game.onboarding.hide()
	game.onboarding.active = false
	game.begin_exploration(game.session.selected_city, {"name":"Barcelona"}, game.session.selected_vehicle, District.START)
	game.camera.reset()
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/driving%s.png" % suffix)
	game.car.recover(District.DESTINATION + Vector3(60, 0, -60), District.START_HEADING)
	game.camera.position = District.LANDMARK_CENTER + Vector3(110, 55, 170)
	game.camera.set_physics_process(false)
	game.camera.look_at(District.LANDMARK_CENTER + Vector3.UP * 55)
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/landmark%s.png" % suffix)
	game.car.recover(District.DESTINATION)
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/discovery%s.png" % suffix)
	game.close_card()
	game.choose_new_location()
	game.onboarding.search_field.text = "Provença"
	game.onboarding._search_now()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/places%s.png" % suffix)
	game.onboarding.hide()
	game.onboarding.active = false
	game.start_at(District.ground(District.AREAS[9].point) if District.AREAS[9].has("point") else District.START)
	game.camera.set_physics_process(true)
	game.camera.reset()
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/city-sant-marti%s.png" % suffix)
	game.toggle_pause()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/city-districts%s.png" % suffix)
	game.queue_free()
	await process_frame
	WorldBuilder.materials.clear()
	quit()
