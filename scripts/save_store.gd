class_name SaveStore
extends RefCounted

var path := "user://journey.json"
var safe_position := District.START
var heading := District.START_HEADING
var discovered: Array[String] = []
var muted := false
var fps := 30
var last_error := ""

func load_journey() -> void:
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1 or data.get("district") not in [District.ID, "sagrada_osm_v2"]:
		return
	var p = data.get("position", [])
	if p is Array and p.size() == 3 and (p[0] is float or p[0] is int) and (p[1] is float or p[1] is int) and (p[2] is float or p[2] is int):
		var candidate := Vector3(p[0], p[1], p[2])
		if District.is_safe(candidate):
			safe_position = candidate
	var h = data.get("heading", 0)
	if (h is float or h is int) and is_finite(float(h)):
		heading = float(h)
	if data.get("discovered", []) is Array and "sagrada_familia" in data.get("discovered", []):
		discovered.assign(["sagrada_familia"])
	muted = data.get("muted", false) == true
	fps = 60 if data.get("fps", 30) == 60 else 30

func write_journey() -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not save this journey."
		return false
	file.store_string(JSON.stringify({"version": 1, "district": District.ID, "position": [safe_position.x, safe_position.y, safe_position.z], "heading": heading, "discovered": discovered, "muted": muted, "fps": fps}))
	file.close()
	var result := DirAccess.rename_absolute(path + ".tmp", path)
	last_error = "" if result == OK else "Could not save this journey."
	return result == OK
