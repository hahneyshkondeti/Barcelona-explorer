class_name RoadNavigation
extends RefCounted

var active := true
var points := PackedVector3Array()
var destination := District.DESTINATION
var destination_name := District.TITLE
var reachable := true
var graph := AStar3D.new()
var ids: Dictionary = {}

func _init() -> void:
	for key in District.DATA.graph.nodes:
		var id := ids.size()
		ids[key] = id
		graph.add_point(id, District.vector(District.DATA.graph.nodes[key]))
	for edge in District.DATA.graph.edges:
		var a: int = ids[edge[0]]
		var b: int = ids[edge[1]]
		if edge[2] == -1:
			graph.connect_points(b, a, false)
		else:
			graph.connect_points(a, b, edge[2] == 0)

func route(from: Vector3) -> PackedVector3Array:
	points.clear()
	reachable = true
	if not active:
		return points
	var start := District.nearest_segment(from)
	var finish := District.nearest_segment(destination)
	var sr: Dictionary = start.road
	var dr: Dictionary = finish.road
	var best_cost := INF
	var best := PackedVector3Array()
	# Same segment can be traveled directly only in a permitted direction.
	if sr.id == dr.id:
		var forward := District.vector(sr.b) - District.vector(sr.a)
		var progress: float = (finish.point - start.point).dot(forward)
		if sr.oneway == 0 or (sr.oneway == 1 and progress >= 0) or (sr.oneway == -1 and progress <= 0):
			best = PackedVector3Array([start.point, finish.point])
			best_cost = start.point.distance_to(finish.point)
	var starts: Array = [sr.a_id, sr.b_id] if sr.oneway == 0 else [sr.b_id if sr.oneway == 1 else sr.a_id]
	var ends: Array = [dr.a_id, dr.b_id] if dr.oneway == 0 else [dr.a_id if dr.oneway == 1 else dr.b_id]
	for a in starts:
		for b in ends:
			var path := graph.get_point_path(ids[a], ids[b])
			if path.is_empty():
				continue
			var cost: float = start.point.distance_to(path[0]) + finish.point.distance_to(path[-1])
			for i in range(1, path.size()):
				cost += path[i - 1].distance_to(path[i])
			if cost < best_cost:
				best_cost = cost
				best = PackedVector3Array([start.point])
				best.append_array(path)
				best.append(finish.point)
	for p in best:
		if points.is_empty() or points[-1].distance_to(p) > 0.1:
			points.append(p)
	reachable = not points.is_empty()
	return points

func distance_remaining() -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total
