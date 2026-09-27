extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message)
	else:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(District.LIGHTS.metadata.render_count > 130000, "Official survey loads citywide lamp coverage")
	var record: Dictionary = District.LIGHTS.cells.values()[0][0]
	var point := District.ground(record.point, 0)
	var key := District.tile_key(Vector2i(floori(point.x/192),floori(point.z/192)))
	check(District.tile(key).street_lights.has(record), "Survey lamps are included in streamed tiles")
	check(District.needed_tiles(point,0).has(key), "Lamp-only tiles are discoverable")
	var lights := StreetLights.new()
	root.add_child(lights)
	lights.set_process(false)
	lights.observer = point
	SolarCycle.current_altitude = 30
	lights.update_lights()
	check(lights.pool.all(func(light): return not light.visible), "Daylight switches street lighting off")
	SolarCycle.current_altitude = -10
	lights.update_lights()
	var active := lights.pool.filter(func(light): return light.visible)
	check(active.size() > 0 and active.size() <= 8, "Night activates a bounded nearby lighting pool")
	check(active.all(func(light): return not light.shadow_enabled), "Street lights avoid costly real-time shadows")
	check(active[0].position.distance_to(point + Vector3.UP*6.9) < 0.01, "Closest light uses surveyed coordinate with terrain-relative height")
	check(StreetLights.night_strength(0) > 0 and StreetLights.night_strength(0) < 1, "Dusk changes light intensity gradually")
	var world := WorldBuilder.new()
	world.is_chunk = true
	world.features = {"roads":[],"trees":[],"buildings":[],"places":[],"addresses":[],"street_lights":[record]}
	root.add_child(world)
	check(world.build_complete, "Mapped lamp geometry builds without road estimates")
	print("RESULT: street lighting checks, %d failures" % failures)
	quit(1 if failures else 0)
