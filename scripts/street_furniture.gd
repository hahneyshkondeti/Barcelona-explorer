class_name StreetFurniture
extends RefCounted

# Shared low-poly geometry is batched with the district, never one mesh per pole.
static var faces: Dictionary = {}

static func face(sides: int, turn: float = 0.0) -> ArrayMesh:
	var key := str(sides) + ":" + str(turn)
	if faces.has(key): return faces[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		for p in [Vector3.ZERO, Vector3(sin(TAU * i / sides + turn), cos(TAU * i / sides + turn), 0), Vector3(sin(TAU * (i + 1) / sides + turn), cos(TAU * (i + 1) / sides + turn), 0)]:
			st.set_normal(Vector3.BACK)
			st.add_vertex(p)
	var mesh := st.commit()
	faces[key] = mesh
	return mesh

static func label(world: WorldBuilder, text: String, at: Vector3, heading: float, pixel: float = 0.008, color: Color = Color.WHITE) -> void:
	var sign := Label3D.new()
	sign.text = WorldBuilder.wrap_street_name(text)
	sign.font_size = 32
	sign.pixel_size = pixel
	sign.modulate = color
	sign.outline_modulate = Color("202b30") if color == Color.WHITE else Color("f1eee4")
	sign.outline_size = 4
	sign.visibility_range_end = 65
	sign.no_depth_test = false
	world.add_child(sign)
	sign.position = at
	sign.rotation.y = heading

static func build(world: WorldBuilder, record: Dictionary) -> void:
	var kind: String = record.kind
	if kind == "metro_station": return # Underground center is not a surface entrance.
	var at := District.vector(record.render_point, 0.13)
	var heading: float = record.heading
	var basis := Basis(Vector3.UP, heading)
	var front := basis * Vector3(0, 0, 0.065)
	var steel := Color("676d70")
	world.instance_box(Vector3(0.075, 2.9, 0.075), at + Vector3.UP * 1.45, heading, steel, true)
	var board := at + Vector3.UP * 2.6
	if kind == "bus_stop" or kind == "metro_entrance":
		var metro := kind == "metro_entrance"
		world.instance_box(Vector3(0.85, 0.85, 0.1), board, heading, Color("bd302c") if metro else Color("24617b"), true)
		label(world, "M" if metro else "BUS", board + front, heading, 0.014 if metro else 0.009)
		var title: String = record.name if not str(record.name).is_empty() else record.station_name
		if title.is_empty(): title = "Metro entrance" if metro else "Bus stop"
		if not str(record.ref).is_empty(): title += " · " + str(record.ref)
		label(world, title, at + Vector3.UP * 3.65, heading, 0.012)
		if not metro and record.tags.get("shelter", "") == "yes":
			var back := basis * Vector3(0, 0, -1.2)
			for side in [-1, 1]:
				world.instance_box(Vector3(0.08, 2.4, 0.08), at + back + basis * Vector3(side * 1.25, 1.2, 0), heading, steel, true)
			world.instance_box(Vector3(2.8, 0.12, 1.4), at + back + Vector3.UP * 2.4, heading, Color("71787b"), true)
			if record.tags.get("bench", "") == "yes":
				world.instance_box(Vector3(2.2, 0.18, 0.45), at + back + Vector3.UP * 0.5, heading, Color("8b8170"), true)
		return
	if kind == "traffic_signal":
		world.instance_box(Vector3(0.38, 1.0, 0.24), board, heading, Color("24292a"), true)
		# Static, unlit lenses: no invented live phases or simulated traffic priority.
		for i in 3:
			var lens := board + Vector3.UP * (0.3 - i * 0.3) + basis * Vector3(0, 0, 0.13)
			world.instance(face(12), Transform3D(basis.scaled_local(Vector3.ONE * 0.12), lens), [Color("572c2c"), Color("65572e"), Color("2c5741")][i], true)
		return
	var code: String = record.tags.get("traffic_sign", "")
	var stop := kind == "stop" or code == "ES:R2"
	var give_way := kind == "give_way" or code in ["ES:R1", "give_way"]
	var speed := code == "maxspeed" or code.begins_with("ES:R301")
	var no_entry := code == "ES:R101"
	if stop or give_way or speed or no_entry:
		var sides := 8 if stop else (3 if give_way else 24)
		var turn := PI if give_way else (PI / 8 if stop else 0.0)
		world.instance(face(sides, turn), Transform3D(basis.scaled_local(Vector3.ONE * 0.43), board), Color("bd302c"), true)
		if give_way or speed:
			world.instance(face(sides, turn), Transform3D(basis.scaled_local(Vector3.ONE * 0.33), board + front), Color("f1eee4"), true)
		if stop: label(world, "STOP", board + front, heading, 0.007)
		if speed:
			var value: String = record.tags.get("maxspeed", "")
			if value.is_empty() and code.begins_with("ES:R301-"): value = code.trim_prefix("ES:R301-")
			if not value.is_empty(): label(world, value, board + front * 2, heading, 0.01, Color("202b30"))
		if no_entry: world.instance_box(Vector3(0.62, 0.14, 0.02), board + front, heading, Color("f1eee4"), true)
	else:
		# Preserve unsupported codes visibly without guessing their pictogram.
		world.instance_box(Vector3(0.8, 0.55, 0.08), board, heading, Color("596267"), true)
		label(world, code if not code.is_empty() else "Mapped sign", board + front, heading, 0.003)
