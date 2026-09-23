extends SceneTree

func _initialize() -> void:
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		quit(1)
		return
	var build := OS.get_environment("BRISA_BUILD_NUMBER")
	if not build.is_valid_int() or int(build) < 1:
		push_error("BRISA_BUILD_NUMBER must be a positive integer")
		quit(1)
		return
	config.set_value("preset.0.options", "application/version", build)
	config.set_value("preset.0.options", "application/provisioning_profile_uuid_release", OS.get_environment("PROFILE_UUID"))
	quit(0 if config.save("res://export_presets.cfg") == OK else 1)
