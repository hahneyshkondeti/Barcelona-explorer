extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: " + message)
	else:
		push_error(message)
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save.path = "user://city_test.json"
	if FileAccess.file_exists(game.save.path): DirAccess.remove_absolute(game.save.path)
	root.add_child(game)
	check(District.AREAS.size() == 10, "All ten Barcelona districts are selectable")
	var origin := District.START
	for i in District.AREAS.size():
		game.explore_area(i)
		var p: Vector3 = game.car.global_position
		check(District.is_safe(p), "Safe street spawn: " + District.AREAS[i].name)
		game.navigation.active = true
		game.navigation.destination = p
		var path: PackedVector3Array = game.navigation.route(origin)
		check(game.navigation.reachable and path.size() > 1, "Cross-city route: " + District.AREAS[i].name)
		check(game.world.loaded_chunks.size() == game.world.desired_chunks.size() and District.tile_cache.size() <= game.world.desired_chunks.size(), "Tile residency follows district, without retaining the city")
		# Compare indexed nearest-road answer to exhaustive geometry for a distant point.
		var nearest := District.nearest_segment(p + Vector3(23,0,17))
		var brute := INF
		var q := Vector2(p.x+23,p.z+17)
		for road in District.ROAD_SEGMENTS:
			brute = minf(brute,q.distance_to(Geometry2D.get_closest_point_to_segment(q,Vector2(road.a[0],road.a[1]),Vector2(road.b[0],road.b[1]))))
		check(absf(brute-nearest.distance) < 0.01, "Spatial road lookup agrees with exhaustive search")
		await process_frame
	# Drive across a tile seam on the known introductory road.
	game.car.recover(District.START, District.START_HEADING)
	game.world.stream_at(game.car.position,true)
	var before: Vector2i = game.world.stream_center
	game.controls.injected = true
	game.controls.throttle = 1
	for i in 700:
		await physics_frame
		if game.world.stream_center != before: break
	check(game.world.stream_center != before and game.car.position.y > -1, "Physical driving crosses a streaming boundary without falling")
	DirAccess.remove_absolute(game.save.path)
	# Drain background work before tearing down its coroutine owners.
	game.world.stream_at(game.car.position, true)
	await process_frame
	await process_frame
	game.queue_free()
	await process_frame
	District.tile_cache.clear()
	WorldBuilder.materials.clear()
	print("RESULT: %d city checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
