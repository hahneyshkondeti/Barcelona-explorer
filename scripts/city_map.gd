class_name CityMap
extends Control

signal point_selected(point: Vector3)
var car: TouringCar
var navigation: RoadNavigation
var center := District.BOUNDS.get_center()
var zoom := 1.0
var selected := Vector3.INF
var atlas: Texture2D
var dragging := false
var dragged := false
var press_position := Vector2.ZERO
var last_position := Vector2.ZERO
var touch_id := -1

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func scale_factor() -> float:
	return minf(size.x / District.BOUNDS.size.x, size.y / District.BOUNDS.size.y) * zoom

func map_point(point: Vector3) -> Vector2:
	return (Vector2(point.x, point.z) - center) * scale_factor() + size * 0.5

func world_point(point: Vector2) -> Vector3:
	var result := (point - size * 0.5) / scale_factor() + center
	return Vector3(result.x, 0.55, result.y)

func change_zoom(factor: float, anchor: Vector2 = Vector2.INF) -> void:
	if not anchor.is_finite(): anchor = size * 0.5
	var before := world_point(anchor)
	zoom = clampf(zoom * factor, 1, 40)
	var after := world_point(anchor)
	center += Vector2(before.x - after.x, before.z - after.z)
	clamp_center()
	queue_redraw()

func clamp_center() -> void:
	center = center.clamp(District.BOUNDS.position, District.BOUNDS.end)

func show_city() -> void:
	if atlas == null: atlas = load("res://data/city/overview.svg")
	center = District.BOUNDS.get_center()
	zoom = 1
	queue_redraw()

func show_car() -> void:
	center = Vector2(car.position.x, car.position.z)
	zoom = 15
	queue_redraw()

func choose(point: Vector2) -> void:
	var target := world_point(point)
	if not District.in_bounds(target, -3): return
	selected = District.nearest_road(target)
	point_selected.emit(target)
	queue_redraw()

func begin_drag(point: Vector2) -> void:
	dragging = true
	dragged = false
	press_position = point
	last_position = point

func move_drag(point: Vector2) -> void:
	if not dragging: return
	if point.distance_to(press_position) > 8: dragged = true
	if dragged:
		center -= (point - last_position) / scale_factor()
		clamp_center()
		queue_redraw()
	last_position = point

func end_drag(point: Vector2) -> void:
	if dragging and not dragged: choose(point)
	dragging = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and touch_id == -1:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: begin_drag(event.position)
			else: end_drag(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: change_zoom(1.5, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: change_zoom(1 / 1.5, event.position)
	elif event is InputEventMouseMotion and touch_id == -1: move_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			begin_drag(event.position)
		elif not event.pressed and event.index == touch_id:
			end_drag(event.position)
			touch_id = -1
	elif event is InputEventScreenDrag and event.index == touch_id: move_drag(event.position)
	accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("193236"))
	var top := map_point(Vector3(District.BOUNDS.position.x, 0, District.BOUNDS.position.y))
	if zoom >= 8:
		draw_rect(Rect2(top, District.BOUNDS.size * scale_factor()), Color("233d40"))
	elif atlas != null: draw_texture_rect(atlas, Rect2(top, District.BOUNDS.size * scale_factor()), false)
	if zoom >= 8: draw_local_streets()
	if zoom < 5:
		for area in District.AREAS:
			var at := BuildingAssets.anchor_position(area.lonlat[0], area.lonlat[1], 0)
			draw_string(ThemeDB.fallback_font, map_point(at), area.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff3d4"))
	if zoom >= 5:
		for record in District.TRANSIT:
			if record.kind == "bus_stop" and zoom < 12: continue
			if record.kind == "metro_entrance" and zoom < 20: continue
			var marker := map_point(District.vector(record.point))
			if not Rect2(Vector2(8, 8), size - Vector2(16, 16)).has_point(marker): continue
			var metro: bool = record.kind != "bus_stop"
			draw_circle(marker, 6, Color("bf413c") if metro else Color("24617b"))
			draw_string(ThemeDB.fallback_font, marker + Vector2(-4, 4), "M" if metro else "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(12, size.y - 12), "M  Metro    B  Bus stop · mapped locations", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff3d4"))
	if is_instance_valid(car): draw_circle(map_point(car.position), 6, Color("fff9e8"))
	if navigation != null and navigation.active: draw_circle(map_point(navigation.destination), 6, Color("f6cf79"))
	if selected.is_finite():
		draw_circle(map_point(selected), 11, Color("f6cf79"), false, 3)
		draw_circle(map_point(selected), 3, Color("f6cf79"))

func draw_local_streets() -> void:
	var lo := world_point(Vector2.ZERO)
	var hi := world_point(size)
	var seen := {}
	var named := {}
	var occupied: Array[Rect2] = []
	var lines := PackedVector2Array()
	var labels: Array = []
	for x in range(floori(lo.x / District.CELL), floori(hi.x / District.CELL) + 1):
		for z in range(floori(lo.z / District.CELL), floori(hi.z / District.CELL) + 1):
			for road in District.road_cells.get(Vector2i(x, z), []):
				if seen.has(road.id): continue
				seen[road.id] = true
				var a := map_point(District.vector(road.a))
				var b := map_point(District.vector(road.b))
				lines.append_array(PackedVector2Array([a, b]))
				var mid := (a + b) * 0.5
				if road.name == "Unnamed mapped way" or named.has(road.name): continue
				var extent := ThemeDB.fallback_font.get_string_size(road.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
				var rect := Rect2(mid - Vector2(4, 20), extent + Vector2(8, 8))
				if not Rect2(Vector2.ZERO, size).encloses(rect): continue
				var crowded := false
				for existing in occupied:
					if existing.intersects(rect): crowded = true; break
				if crowded: continue
				named[road.name] = true
				occupied.append(rect)
				labels.append([mid, road.name])
	if not lines.is_empty(): draw_multiline(lines, Color("91a49a"), 2.0, true)
	for item in labels:
		draw_string(ThemeDB.fallback_font, item[0] + Vector2(0, -4), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff3d4"))
