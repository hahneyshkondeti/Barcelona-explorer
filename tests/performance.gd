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
	var navigation := RoadNavigation.new()
	var started := Time.get_ticks_usec()
	var path := navigation.route(District.START)
	var search_usec := Time.get_ticks_usec() - started
	var searches := navigation.search_count
	var distance := navigation.distance_remaining()
	started = Time.get_ticks_usec()
	for i in 100: navigation.route(District.START)
	var cached_usec := (Time.get_ticks_usec() - started) / 100.0
	check(navigation.search_count == searches, "Stationary route refreshes perform no city graph searches")
	check(absf(navigation.distance_remaining() - distance) < 0.1, "Cached route preserves remaining distance")
	if path.size() > 1:
		navigation.route(path[0].lerp(path[1], 0.5))
		check(navigation.distance_remaining() <= distance, "Following route trims travelled distance")
	navigation.destination = District.nearest_road(District.START + Vector3(400, 0, 400))
	navigation.route(District.START)
	check(navigation.search_count > searches, "Destination change triggers a new directed search")
	searches = navigation.search_count
	navigation.route(District.START + Vector3(500, 0, 500))
	check(navigation.search_count > searches, "Off-route movement triggers a fresh search")
	navigation.active = false
	check(navigation.route(District.START).is_empty(), "Disabling navigation clears the cached route")
	print("TIMING: first route %dus, cached refresh mean %.1fus" % [search_usec, cached_usec])

	var key := ""
	var count := 0
	for candidate in District.needed_tiles(District.START, 1):
		var size: int = District.tile(candidate).buildings.size()
		if size > count:
			count = size
			key = candidate
	var chunk := WorldBuilder.new()
	chunk.is_chunk = true
	chunk.incremental = true
	chunk.features = District.tile(key)
	root.add_child(chunk)
	check(not chunk.build_complete, "Dense background tile yields instead of completing in one frame")
	var frames := 0
	while not chunk.build_complete and frames < 2000:
		await process_frame
		frames += 1
	check(chunk.build_complete, "Incremental tile finishes within bounded frame count")
	var collider := false
	for child in chunk.get_children():
		if child is StaticBody3D: collider = true
	check(collider, "Incremental tile retains building collision geometry")
	print("TIMING: dense tile %s (%d buildings) spread over %d frames" % [key,count,frames])
	chunk.free()
	# Recovery can interrupt an unfinished tile without leaving stale geometry.
	var world := WorldBuilder.new()
	root.add_child(world)
	world.load_chunk(key, true)
	world.stream_at(District.START, true)
	var complete := true
	for loaded in world.loaded_chunks.values():
		complete = complete and loaded.build_complete
	check(complete, "Recovery replaces pending geometry with complete collision tiles")
	# Let retired coroutine builders unwind before tearing down the scene.
	await process_frame
	await process_frame
	world.free()
	await process_frame
	print("RESULT: %d performance checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
