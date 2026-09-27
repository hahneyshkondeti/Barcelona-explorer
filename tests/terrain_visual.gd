extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := WorldBuilder.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.far = 16000
	camera.current = true
	root.add_child(camera)
	for site in [
		{"id":"collserola", "lon":2.1185,"lat":41.4225,"offset":Vector3(180,180,280),"look":Vector3(0,-70,0)},
		{"id":"coast", "lon":2.1900,"lat":41.379,"offset":Vector3(190,170,230),"look":Vector3(0,0,0)},
		{"id":"montjuic", "lon":2.1648,"lat":41.365,"offset":Vector3(180,150,220),"look":Vector3(0,-20,0)}]:
		var p := TerrainData.ground(BuildingAssets.anchor_position(site.lon,site.lat,0))
		world.stream_at(p, true)
		camera.position = p + site.offset
		camera.look_at(p + site.look)
		for i in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/brisa-terrain-%s.png" % site.id)
		print("Captured " + site.id)
	world.free()
	camera.free()
	await process_frame
	quit()
