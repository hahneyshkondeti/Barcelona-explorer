class_name PublicSpaces
extends RefCounted

static var column_mesh: CylinderMesh
static var taper_mesh: CylinderMesh
static var water: ShaderMaterial

static func prepare() -> void:
	if column_mesh != null: return
	column_mesh = CylinderMesh.new()
	column_mesh.top_radius = 0.5
	column_mesh.bottom_radius = 0.5
	column_mesh.height = 1
	column_mesh.radial_segments = 16
	taper_mesh = CylinderMesh.new()
	taper_mesh.top_radius = 0.5
	taper_mesh.bottom_radius = 0.25
	taper_mesh.height = 1
	taper_mesh.radial_segments = 16
	water = ShaderMaterial.new()
	water.shader = load("res://assets/shaders/fountain_water.gdshader")

static func cylinder(world: WorldBuilder, at: Vector3, radius: float, height: float, color: Color, taper: bool = false) -> void:
	world.instance(taper_mesh if taper else column_mesh, Transform3D(Basis.IDENTITY.scaled(Vector3(radius * 2, height, radius * 2)), at), color, false)

static func segment(world: WorldBuilder, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var up := (b - a).normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.1: right = Vector3.RIGHT
	var basis := Basis(right, up, right.cross(up)).scaled_local(Vector3(radius * 2, a.distance_to(b), radius * 2))
	world.instance(column_mesh, Transform3D(basis, (a + b) * 0.5), color, true)

static func jet(world: WorldBuilder, from: Vector3, to: Vector3, height: float) -> void:
	var previous := from
	for i in range(1, 13):
		var t := i / 12.0
		var p := from.lerp(to, t) + Vector3.UP * (4 * height * t * (1 - t))
		segment(world, previous, p, 0.05, Color("c2e5df"))
		previous = p

static func wall(world: WorldBuilder, ring: Array, height: float, width: float, collision: bool) -> void:
	for i in ring.size():
		var a := District.vector(ring[i], 0)
		var b := District.vector(ring[(i + 1) % ring.size()], 0)
		if a.distance_to(b) < 0.02: continue
		world.instance_box(Vector3(width, height, a.distance_to(b) + width * 0.5), (a + b) * 0.5 + Vector3.UP * (height * 0.5), atan2(b.x - a.x, b.z - a.z), Color("c6ba9f"), false)
		if collision:
			var high_a := a + Vector3.UP * maxf(height, 1.0)
			var high_b := b + Vector3.UP * maxf(height, 1.0)
			world.collision_quad(PackedVector3Array([a, high_a, high_b, a, high_b, b]))

static func inside(point: Vector3, ring: Array) -> bool:
	var polygon := PackedVector2Array()
	for p in ring: polygon.append(Vector2(p[0], p[1]))
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), polygon)

static func fountain(world: WorldBuilder, feature: Dictionary) -> void:
	world.base_elevation = TerrainData.height(feature.point[0], feature.point[1])
	var ring: Array = feature.rings[0]
	world.flat_polygon(ring, 0.28, water)
	wall(world, ring, 0.65, 0.4, true)
	for hole in feature.rings.slice(1):
		world.flat_polygon(hole, 0.34, WorldBuilder.material(Color("c6ba9f")))
		wall(world, hole, 0.45, 0.25, false)
	if feature.kind != "fountain": return
	var center := District.vector(feature.point, 0.35)
	# Architectural water display, not a claim about current fountain operation.
	if feature.id == "way/126832508":
		monument(world, center)
		return
	if not inside(center, ring): return
	var radius := 100.0
	for p in ring: radius = minf(radius, center.distance_to(District.vector(p, 0.35)))
	radius = minf(radius * 0.65, 6.0)
	if radius < 0.6: return
	cylinder(world, center, 0.6, 0.15, Color("bcb49c"))
	for i in 12:
		var angle := i * TAU / 12
		var end := center + Vector3(sin(angle), 0, cos(angle)) * radius
		var blocked := false
		for hole in feature.rings.slice(1):
			if inside(center, hole) or inside(end, hole): blocked = true
		if not blocked: jet(world, center, end, minf(3.5, radius * 0.65))

static func mosaic(world: WorldBuilder, feature: Dictionary) -> void:
	var center := District.vector(feature.point, 0.085)
	var radius := 100.0
	for p in feature.rings[0]: radius = minf(radius, center.distance_to(District.vector(p, 0.085)))
	world.flat_polygon(feature.rings[0], 0.082, WorldBuilder.material(Color("c2b8a2")))
	for i in 16:
		var angle := i * TAU / 16 + 0.7
		var tip := center + Vector3(sin(angle), 0, cos(angle)) * radius * (0.94 if i % 2 == 0 else 0.62)
		for side in [-1, 1]:
			var inner := center + Vector3(sin(angle + side * 0.18), 0, cos(angle + side * 0.18)) * radius * 0.23
			world.flat_polygon([[center.x,center.z],[tip.x,tip.z],[inner.x,inner.z]], 0.086, WorldBuilder.material(Color("4e5e60") if side == -1 else Color("a07059")))

static func monument(world: WorldBuilder, center: Vector3) -> void:
	# Jujol's triangular composition and published 33 m overall height; fine
	# sculpture and vertical dimensions are an original low-poly interpretation.
	var stone := Color("cbb997")
	var dark := Color("4d625a")
	for tier in 4:
		var points: Array = []
		for i in 3:
			var angle := i * TAU / 3 + 0.15
			points.append([center.x + sin(angle) * (8.0 - tier * 0.6), center.z + cos(angle) * (8.0 - tier * 0.6)])
		world.flat_polygon(points, 0.8 + tier * 0.5, WorldBuilder.material(stone))
		wall(world, points, 0.8 + tier * 0.5, 0.28, false)
	var core_material := WorldBuilder.material(stone).duplicate() as StandardMaterial3D
	core_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var core: Array = []
	for i in 3:
		var angle := i * TAU / 3 + 0.15
		core.append(center + Vector3(sin(angle), 0, cos(angle)) * 5.0)
	for i in 3:
		var a: Vector3 = core[i] + Vector3.UP * 2.3
		var b: Vector3 = core[(i + 1) % 3] + Vector3.UP * 2.3
		world.quad(world.surface(center, core_material), a, b, b + Vector3.UP * 15, a + Vector3.UP * 15, a.distance_to(b), 15)
		for level in [2.5, 7.0, 17.0]:
			world.instance_box(Vector3(0.5, 0.6, a.distance_to(b)), (a+b)*0.5 + Vector3.UP * level, atan2(b.x-a.x,b.z-a.z), Color("b8a486"), false)
	for i in 3:
		var angle := i * TAU / 3 + 0.15
		var outward := Vector3(sin(angle), 0, cos(angle))
		var foot := center + outward * 5.3
		cylinder(world, foot + Vector3.UP * 3.0, 1.5, 1.5, stone)
		cylinder(world, foot + Vector3.UP * 10.6, 0.85, 14.0, stone)
		for flute in 12:
			var f := flute * TAU / 12
			cylinder(world, foot + Vector3(sin(f) * 0.78, 10.6, cos(f) * 0.78), 0.08, 13.4, Color("af9d80"))
		cylinder(world, foot + Vector3.UP * 18.0, 1.45, 0.75, stone, true)
		world.instance_box(Vector3(3.0, 0.6, 3.0), foot + Vector3.UP * 18.65, angle, stone, false)
		# Abstract statuary masses at the three documented sculptural groups.
		var group := center + outward * 6.4
		for figure in 3:
			var tangent := Vector3(outward.z, 0, -outward.x)
			var body := group + tangent * (figure - 1) * 0.85
			cylinder(world, body + Vector3.UP * 4.6, 0.48, 2.5, Color("c2b69c"), true)
			world.instance(world.leaves, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.7), body + Vector3.UP * 6.2), stone, false)
		jet(world, center + outward * 6 + Vector3.UP * 1.1, center + outward * 10, 1.2)
	cylinder(world, center + Vector3.UP * 20.5, 3.3, 3.5, stone, true)
	cylinder(world, center + Vector3.UP * 24.2, 2.5, 4.0, stone)
	cylinder(world, center + Vector3.UP * 27.4, 3.5, 1.6, stone, true)
	for i in 3:
		var angle := i * TAU / 3
		var at := center + Vector3(sin(angle) * 1.8, 29.3, cos(angle) * 1.8)
		cylinder(world, at, 0.45, 2.7, dark, true)
		world.instance(world.leaves, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.6), at + Vector3.UP * 1.65), dark, false)
	cylinder(world, center + Vector3.UP * 31.6, 2.4, 1.6, dark, true)
	cylinder(world, center + Vector3.UP * 32.5, 2.6, 0.3, dark)

static func yield_budget(world: WorldBuilder) -> void:
	if world.incremental and world.budget_expired():
		await world.get_tree().process_frame
		world.slice_started = Time.get_ticks_usec()

static func build(world: WorldBuilder, site: Dictionary) -> void:
	prepare()
	world.flat_polygon(site.rings[0], 0.08, world.pavement)
	if site.site == "espanya": wall(world, site.rings[0], 0.32, 0.45, true)
	for feature in site.features:
		await yield_budget(world)
		if world.retired: return
		if feature.kind == "garden":
			world.flat_polygon(feature.rings[0], 0.12, WorldBuilder.material(Color("677751")))
			wall(world, feature.rings[0], 0.18, 0.25, false)
			for hole in feature.rings.slice(1): world.flat_polygon(hole, 0.13, world.pavement)
	for feature in site.features:
		await yield_budget(world)
		if world.retired: return
		if feature.kind in ["water", "fountain"]:
			fountain(world, feature)
			world.base_elevation = NAN
		elif feature.kind == "mosaic": mosaic(world, feature)
		elif feature.kind == "bench":
			var at := District.vector(feature.point, 0)
			var toward := District.vector(site.point, 0) - at
			var heading := atan2(toward.x, toward.z)
			world.instance_box(Vector3(1.8, 0.15, 0.5), at + Vector3.UP * 0.5, heading, Color("97836a"), true)
			for side in [-1, 1]:
				world.instance_box(Vector3(0.12, 0.5, 0.4), at + Basis(Vector3.UP, heading) * Vector3(side * 0.65, 0.25, 0), heading, Color("4f5855"), true)
