extends SceneTree
# Run with a real renderer, not --headless. Uses a disposable save.
# Repeat on the same hardware/rendering settings; this is not an iPhone benchmark.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save.path = "user://benchmark_journey.json"
	if FileAccess.file_exists(game.save.path): DirAccess.remove_absolute(game.save.path)
	root.add_child(game)
	Engine.max_fps = 60
	game.controls.injected = true
	game.car.recover(District.START, District.START_HEADING)
	game.world.stream_at(game.car.position, true)
	game.camera.reset()
	for i in 120: await process_frame
	var initial_cell: Vector2i = game.world.stream_center
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 720:
		if game.is_paused: game.set_paused(false)
		game.controls.throttle = 1.0
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
	var crossed: bool = initial_cell != game.world.stream_center
	game.controls.throttle = 0
	samples.sort()
	var over_50 := 0
	var over_100 := 0
	for value in samples:
		if value > 50: over_50 += 1
		if value > 100: over_100 += 1
	print("FRAME_PROFILE: ", JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"frames":samples.size(),"p50_ms":samples[360],"p95_ms":samples[684],"p99_ms":samples[712],"max_ms":samples[-1],"over_50ms":over_50,"over_100ms":over_100,"crossed_tile":crossed}))
	# Finish pending work before teardown so cancellation isn't part of the sample.
	game.world.stream_at(game.car.position, true)
	await process_frame
	await process_frame
	game.free()
	if FileAccess.file_exists("user://benchmark_journey.json"): DirAccess.remove_absolute("user://benchmark_journey.json")
	await process_frame
	quit()
