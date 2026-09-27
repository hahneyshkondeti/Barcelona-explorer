extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: " + message)
	else:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")
func point(lon: float, lat: float) -> Vector3:
	return BuildingAssets.anchor_position(lon, lat, 0)
func run() -> void:
	check(TerrainData.samples.size() == TerrainData.columns * TerrainData.rows, "Complete offline terrain grid")
	var tibidabo := point(2.1185, 41.4225)
	var montjuic := point(2.1660, 41.3634)
	var sea := point(2.205, 41.375)
	check(TerrainData.height(tibidabo.x, tibidabo.z) > 480, "Tibidabo rises above 480 metres")
	check(TerrainData.height(montjuic.x, montjuic.z) > 150, "Montjuïc rises above 150 metres")
	check(TerrainData.height(sea.x, sea.z) < 0, "Mapped Mediterranean is below sea surface")
	check(District.START.y > 20 and District.is_safe(District.START), "Starting road is elevated and safe")
	var terrain := TerrainWorld.new()
	root.add_child(terrain)
	var road := District.nearest_road(tibidabo)
	terrain.stream_at(road)
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(road + Vector3.UP * 100, road - Vector3.UP * 100)
	var hit := terrain.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and absf(hit.position.y - TerrainData.height(road.x, road.z)) < 0.03, "Terrain collision matches height lookup on mountain road")
	check(terrain.patches.size() == 25, "Detailed terrain streaming remains bounded")
	terrain.stream_at(District.START)
	await physics_frame
	check(terrain.patches.size() == 25, "Teleport replaces old terrain patches")
	var save := SaveStore.new()
	save.path = "user://terrain-migration-test.json"
	var file := FileAccess.open(save.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"district":District.ID,"position":[road.x,0.55,road.z],"discovered":["sagrada_familia"]}))
	file.close()
	save.load_journey()
	check(absf(save.safe_position.y - road.y) < 0.05 and "sagrada_familia" in save.discovered, "Flat-world save migrates altitude and preserves discoveries")
	save.write_journey()
	var loaded := SaveStore.new()
	loaded.path = save.path
	loaded.load_journey()
	check(loaded.safe_position.distance_to(road) < 0.05, "Elevated save round-trips")
	DirAccess.remove_absolute(save.path)
	# Exercise real road grades through CharacterBody3D, in both directions.
	var slope: Dictionary = {}
	for segment in District.ROAD_SEGMENTS:
		var a := District.ground(segment.a)
		var b := District.ground(segment.b)
		var length := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		var grade := absf(b.y - a.y) / maxf(length, 1)
		if length > 85 and grade > 0.07 and grade < 0.16 and a.y > 100:
			slope = segment
			break
	check(not slope.is_empty(), "Mapped long hillside road exists for driving test")
	if not slope.is_empty():
		var a := District.ground(slope.a)
		var b := District.ground(slope.b)
		if a.y > b.y:
			var swap := a
			a = b
			b = swap
		var builder := WorldBuilder.new()
		builder.prepare_materials()
		builder.strip(a, b, 8, 0.09, builder.asphalt)
		var conforms := true
		for st in builder.surfaces.values():
			var mesh: ArrayMesh = st.commit()
			var faces := mesh.get_faces()
			for i in range(0, faces.size(), 3):
				var mid := (faces[i] + faces[i+1] + faces[i+2]) / 3.0
				conforms = conforms and absf(mid.y - TerrainData.height(mid.x, mid.z) - 0.09) < 0.015
		check(conforms, "Road triangles conform between vertices without cutting through hills")
		builder.free()
		var controls := DriveInput.new()
		controls.injected = true
		var car := TouringCar.new()
		car.controls = controls
		root.add_child(car)
		for uphill in [true, false]:
			var from := a if uphill else b
			var to := b if uphill else a
			var direction := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
			car.recover(from + direction * 8, atan2(-direction.x, -direction.z))
			terrain.stream_at(car.position)
			controls.throttle = 0
			for i in 20: await physics_frame
			var start := car.position
			controls.throttle = 0.55
			for i in 180: await physics_frame
			var rise := car.position.y - start.y
			check((rise > 0.5 if uphill else rise < -0.5) and car.position.distance_to(start) > 8, "Car physically drives " + ("uphill" if uphill else "downhill"))
			check(absf(car.position.y - TerrainData.height(car.position.x, car.position.z)) < 1.5, "Car stays on the sloped collision surface")
			controls.throttle = 0
			controls.brake = 1
			for i in 45: await physics_frame
			check(absf(car.speed) < 1, "Braking stops the car on a grade")
			controls.brake = 0
		car.free()
		controls.free()
	terrain.free()
	await process_frame
	print("RESULT: %d terrain checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
