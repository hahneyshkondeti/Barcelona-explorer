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
	var samples := {}
	var mapped := 0
	for key in District.INFRASTRUCTURE.cells:
		var data := District.tile(key)
		mapped += data.infrastructure.size()
		for record in data.infrastructure:
			if not samples.has(record.kind): samples[record.kind] = record
		District.tile_cache.erase(key)
	var expected := 0
	for count in District.INFRASTRUCTURE.metadata.counts.values(): expected += int(count)
	check(mapped == expected, "All shipped mapped features attach to streamable tiles")
	check(District.TRANSIT.size() == int(District.INFRASTRUCTURE.metadata.counts.metro_station) + int(District.INFRASTRUCTURE.metadata.counts.metro_entrance) + int(District.INFRASTRUCTURE.metadata.counts.bus_stop), "Station, entrance and bus-stop search catalog is populated")
	var lookup := AddressSearch.new()
	var results := lookup.search("Metro Sagrada Família")
	check(not results.is_empty() and str(results[0].category).begins_with("Metro"), "Named metro stations or entrances can be found in Places")
	var bus_results := lookup.search("Bus stop")
	check(not bus_results.is_empty() and bus_results[0].category == "Bus stop", "Bus stops are searchable by category")
	var world := WorldBuilder.new()
	world.is_chunk = true
	world.features = {"roads":[], "parks":[], "buildings":[], "trees":[], "addresses":[], "places":[]}
	root.add_child(world)
	var original_children := world.get_child_count()
	StreetFurniture.build(world, samples.metro_station)
	check(world.get_child_count() == original_children and world.batches.is_empty(), "Underground station center never invents a surface structure")
	for kind in samples:
		if kind != "metro_station": StreetFurniture.build(world, samples[kind])
	check(not world.batches.is_empty(), "Mapped street furniture builds shared mesh batches")
	check(StreetFurniture.face(24) == StreetFurniture.face(24), "Round sign geometry is reused")
	await world.flush_batches()
	var labels := 0
	for child in world.get_children():
		if child is Label3D:
			labels += 1
			check(child.visibility_range_end <= 65, "Furniture labels have a bounded visibility distance")
	check(labels >= 3, "Transit poles and supported signs have readable labels")
	world.free()
	await process_frame
	print("RESULT: %d infrastructure checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
