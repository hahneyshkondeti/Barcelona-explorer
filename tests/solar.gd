extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message)
	else:
		push_error(message)
		failures += 1
func sample(date: String) -> Dictionary:
	return SolarCycle.position_at(Time.get_unix_time_from_datetime_string(date), 41.4036, 2.1744)
func _initialize() -> void:
	var noon := sample("2026-03-20T12:00:00")
	check(noon.altitude > 47 and noon.altitude < 51 and noon.direction.z > 0.5, "Equinox noon sun is high in Barcelona's southern sky")
	var morning := sample("2026-06-21T06:00:00")
	var evening := sample("2026-06-21T18:00:00")
	check(morning.direction.x > 0 and evening.direction.x < 0, "Sun moves from east in the morning to west in the evening")
	check(sample("2026-06-21T12:00:00").altitude > 70 and sample("2026-12-21T12:00:00").altitude < 27, "Season changes midday solar elevation")
	check(sample("2026-09-27T00:00:00").altitude < -30, "Nighttime sun stays below the horizon")
	check(sample("2026-09-27T05:00:00").altitude < 0 and sample("2026-09-27T07:00:00").altitude > 0, "Barcelona sunrise crosses the horizon at the expected UTC interval")
	check(sample("2026-09-27T17:00:00").altitude > 0 and sample("2026-09-27T19:00:00").altitude < 0, "Barcelona sunset crosses the horizon at the expected UTC interval")
	var later := sample("2026-03-20T12:01:00")
	check(noon.direction.distance_to(later.direction) > 0.001, "Sun follows real elapsed time")
	print("RESULT: solar checks, %d failures" % failures)
	quit(1 if failures else 0)
