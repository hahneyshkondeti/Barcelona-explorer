class_name StreetLights
extends Node3D

# Positions are surveyed. This fallback fixture and photometry are illustrative.
const HEAD_COLOR := Color("ffe4a3")
const HEIGHT := 7.0
const MAX_ACTIVE := 8
static var glow: StandardMaterial3D
static var pole_mesh: CylinderMesh
var observer := Vector3.ZERO
var pool: Array[SpotLight3D] = []
var elapsed := 1.0

static func night_strength(altitude: float) -> float:
	return 1.0 - smoothstep(-3.0, 2.0, altitude)

static func lens_material() -> StandardMaterial3D:
	if glow == null:
		glow = StandardMaterial3D.new()
		glow.albedo_color = HEAD_COLOR
		glow.emission_enabled = true
		glow.emission = HEAD_COLOR
		glow.emission_energy_multiplier = 0
	return glow

static func build(world: WorldBuilder, record: Dictionary) -> void:
	var at := District.vector(record.point, 0)
	if pole_mesh == null:
		pole_mesh = CylinderMesh.new()
		pole_mesh.top_radius = 0.055
		pole_mesh.bottom_radius = 0.12
		pole_mesh.height = 1
		pole_mesh.radial_segments = 8
	world.instance(pole_mesh, Transform3D(Basis.IDENTITY.scaled(Vector3(1, HEIGHT, 1)), at + Vector3.UP * HEIGHT * 0.5), Color("444b4a"), false)
	world.instance_box(Vector3(0.7, 0.14, 0.5), at + Vector3.UP * HEIGHT, 0, Color("444b4a"), false)
	world.instance_box(Vector3(0.6, 0.035, 0.4), at + Vector3.UP * (HEIGHT - 0.09), 0, HEAD_COLOR, true)

func _ready() -> void:
	for i in MAX_ACTIVE:
		var light := SpotLight3D.new()
		light.rotation.x = -PI / 2
		light.spot_range = 19
		light.spot_angle = 68
		light.spot_attenuation = 1.3
		light.light_color = HEAD_COLOR
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		pool.append(light)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.5: return
	elapsed = 0
	update_lights()

func update_lights() -> void:
	var strength := night_strength(SolarCycle.current_altitude)
	lens_material().emission_energy_multiplier = strength * 2.5
	for light in pool: light.visible = false
	if strength <= 0: return
	var candidates: Array = []
	var cell := Vector2i(floori(observer.x / District.CELL), floori(observer.z / District.CELL))
	for x in range(cell.x - 1, cell.x + 2):
		for z in range(cell.y - 1, cell.y + 2):
			for record in District.LIGHTS.cells.get(District.tile_key(Vector2i(x,z)), []):
				var p := District.ground(record.point, HEIGHT - 0.1)
				var distance := Vector2(p.x-observer.x,p.z-observer.z).length_squared()
				if distance < 65 * 65: candidates.append({"point":p,"distance":distance})
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	for i in mini(pool.size(), candidates.size()):
		pool[i].position = candidates[i].point
		pool[i].light_energy = strength * 3.5
		pool[i].visible = true
