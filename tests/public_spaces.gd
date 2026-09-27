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
func run() -> void:
	var lookup := AddressSearch.new()
	for query in ["Plaça de Catalunya", "Plaza Espana"]:
		var results := lookup.search(query)
		check(not results.is_empty() and results[0].category == "Square and fountains", "Named square ranks ahead of ordinary address matches: " + query)
	var world := WorldBuilder.new()
	root.add_child(world)
	for site in District.PUBLIC_SPACES.sites:
		var position := District.ground(site.point)
		world.stream_at(position, true)
		var copies := 0
		for chunk in world.loaded_chunks.values():
			for space in chunk.features.get("public_spaces", []):
				if space.site == site.site: copies += 1
		check(copies == 1, "Square streamed exactly once across tile boundaries: " + site.name)
		var safe := District.nearest_road(position)
		check(District.is_safe(safe), "Square launch point remains on a driveable road: " + site.name)
		await physics_frame
		var fountain: Dictionary = {}
		for feature in site.features:
			if feature.kind == "fountain": fountain = feature; break
		var a := District.vector(fountain.rings[0][0], 0.6)
		var b := District.vector(fountain.rings[0][1], 0.6)
		var mid := (a+b)*0.5
		mid.y += TerrainData.height(fountain.point[0], fountain.point[1])
		var normal := (b-a).normalized().cross(Vector3.UP)
		var ray := PhysicsRayQueryParameters3D.create(mid+normal*1.5, mid-normal*1.5)
		check(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Fountain basin rim blocks cars: " + site.name)
		if "--capture" in OS.get_cmdline_user_args():
			var camera := Camera3D.new()
			root.add_child(camera)
			camera.position = position + (Vector3(95, 140, 115) if site.site == "catalunya" else Vector3(70, 65, 80))
			camera.look_at(position + Vector3.UP * (7 if site.site == "espanya" else 0))
			camera.current = true
			for i in 12: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/brisa-square-%s.png" % site.site)
			camera.free()
	world.free()
	await process_frame
	print("RESULT: %d public space checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
