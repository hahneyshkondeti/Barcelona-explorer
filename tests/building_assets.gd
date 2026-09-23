extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var adapter := BuildingAssets.new()
	var building: Dictionary = District.nearby_features(District.START).buildings[0]
	var entry := {"id":"test","scene":"res://assets/buildings/_test_only/triangle.gltf","building_ids":[building.id],"anchor_lonlat":District.DATA.origin_lonlat,"elevation_m":2,"yaw_degrees":45,"scale":2,"visibility_m":200,"source":{"url":"local original test fixture","license":"Original project test geometry","license_url":"local test fixture","attribution":"Brisa test triangle","capture_date":"not applicable"}}
	adapter.install(parent, {"schema":1,"assets":[entry]}, District.DATA.buildings, false)
	check(adapter.replaced.has(building.id) and parent.get_child_count() == 1, "Imported glTF replaces the selected footprint")
	if parent.get_child_count():
		var model: Node3D = parent.get_child(0)
		check(model.position.is_equal_approx(Vector3(0,2,0)) and is_equal_approx(model.rotation.y, PI/4) and model.scale.is_equal_approx(Vector3.ONE*2), "Geographic anchor, elevation, orientation and scale are applied")
	check(BuildingAssets.active_credits.size() == 1, "Successful assets expose source credits")
	var builder := WorldBuilder.new()
	builder.building_assets.replaced[building.id] = true
	builder.plaster.append(ShaderMaterial.new())
	builder.build_building(building)
	check(not builder.wall_faces.is_empty() and builder.surfaces.is_empty() and builder.batches.is_empty(), "Replacement keeps footprint collision and suppresses procedural visual geometry")
	builder.free()
	var missing := entry.duplicate(true)
	missing.scene = "res://assets/buildings/missing.glb"
	adapter.install(parent, {"schema":1,"assets":[missing]}, District.DATA.buildings, false)
	check(adapter.replaced.is_empty() and adapter.issues.size() == 1 and parent.get_child_count() == 0, "Missing model preserves fallback and clears prior installed instance")
	var invalid := entry.duplicate(true)
	invalid.scale = -1
	adapter.install(parent, {"schema":1,"assets":[invalid]}, District.DATA.buildings, false)
	check(adapter.replaced.is_empty(), "Invalid transform cannot hide a building")
	invalid = entry.duplicate(true)
	invalid.source.erase("license")
	adapter.install(parent, {"schema":1,"assets":[invalid]}, District.DATA.buildings, false)
	check(adapter.replaced.is_empty(), "Missing license metadata preserves fallback")
	invalid = entry.duplicate(true)
	invalid.building_ids = ["way/unknown"]
	adapter.install(parent, {"schema":1,"assets":[invalid]}, District.DATA.buildings, false)
	check(adapter.replaced.is_empty(), "Unknown footprint IDs are rejected")
	adapter.install(parent, {"schema":1,"assets":[entry,entry]}, District.DATA.buildings, false)
	check(adapter.replaced.size() == 1 and adapter.issues.size() == 1, "Overlapping replacements are rejected")
	var mobile := entry.duplicate(true)
	mobile.mobile_scene = "res://assets/buildings/missing-mobile.glb"
	adapter.install(parent, {"schema":1,"assets":[mobile]}, District.DATA.buildings, true)
	check(adapter.replaced.is_empty(), "Missing mobile variant falls back rather than loading desktop geometry")
	adapter.install(parent, {"schema":99,"assets":[]}, District.DATA.buildings, false)
	check(adapter.replaced.is_empty() and adapter.issues.size() == 1, "Unknown manifest version preserves fallback")
	parent.free()
	BuildingAssets.active_credits.clear()
	print("RESULT: %d asset integration checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
