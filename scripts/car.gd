class_name TouringCar
extends CharacterBody3D

var controls: DriveInput
var speed := 0.0
var steer_visual := 0.0
var paused := false
var collided := false
var body: Node3D
var front_wheels: Array[Node3D] = []
const MAX_SPEED := 23.0
const REVERSE_SPEED := 7.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.85, 1.1, 3.7)
	shape.shape = box
	shape.position.y = 0.45
	add_child(shape)
	body = Node3D.new()
	add_child(body)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("617778")
	paint.metallic = 0.65
	paint.roughness = 0.27
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.7
	profile_mesh([
		Vector4(0.78, 0.15, -1.75, 1.72),
		Vector4(0.94, 0.42, -1.88, 1.83),
		Vector4(0.89, 0.75, -1.65, 1.65),
		Vector4(0.78, 0.86, -1.35, 1.3)], paint)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("263a43")
	glass.metallic = 0.6
	glass.roughness = 0.16
	profile_mesh([Vector4(0.77, 0.84, -1.1, 1.15), Vector4(0.65, 1.42, -0.53, 0.71)], glass)
	profile_mesh([Vector4(0.67, 1.42, -0.56, 0.74), Vector4(0.61, 1.49, -0.49, 0.66)], paint)
	for x in [-0.73, 0.73]:
		WorldBuilder.box(body, Vector3(0.07, 0.6, 0.1), Vector3(x, 1.12, 0.2), Color("617778"))
		WorldBuilder.box(body, Vector3(0.25, 0.14, 0.3), Vector3(x * 1.3, 0.95, -0.65), Color("617778"))
	WorldBuilder.box(body, Vector3(1.55, 0.12, 0.09), Vector3(0, 0.28, 1.8), Color("383c3d"))
	WorldBuilder.box(body, Vector3(0.45, 0.13, 0.035), Vector3(0, 0.53, 1.84), Color("d9d8cd"))
	for x in [-0.96, 0.96]:
		for z in [-1.13, 1.13]:
			var pivot := Node3D.new()
			body.add_child(pivot)
			pivot.position = Vector3(x, 0.29, z)
			var wheel := WorldBuilder.cylinder(pivot, 0.39, 0.26, Vector3.ZERO, Color("23333b"))
			wheel.rotation.z = PI / 2
			var hub := WorldBuilder.cylinder(pivot, 0.23, 0.28, Vector3.ZERO, Color("8a9398"))
			hub.rotation.z = PI / 2
			if z < 0:
				front_wheels.append(pivot)
	for x in [-0.63, 0.63]:
		WorldBuilder.box(body, Vector3(0.38, 0.2, 0.04), Vector3(x, 0.54, -1.84), Color("fff4cd"))
		WorldBuilder.box(body, Vector3(0.35, 0.16, 0.04), Vector3(x, 0.5, 1.84), Color("ac3036"))
	WorldBuilder.box(body, Vector3(1.6, 0.12, 0.12), Vector3(0, 0.19, -1.86), Color("c3c5b9"))

func _physics_process(delta: float) -> void:
	if paused or controls == null:
		return
	controls.sample()
	var gas := controls.throttle
	var stop := controls.brake
	# Brake to a stop first; holding the same pedal then engages reverse.
	if stop > 0:
		if speed > 0.15:
			speed = move_toward(speed, 0, 20 * delta)
		else:
			speed = move_toward(speed, -REVERSE_SPEED, 6 * delta)
	elif gas > 0:
		speed = move_toward(speed, MAX_SPEED, (14.0 if speed < 0 else 8.5) * delta)
	else:
		speed = move_toward(speed, 0, 2.8 * delta)
	steer_visual = move_toward(steer_visual, controls.steering, delta * 5)
	var turn := 0.7 * steer_visual * clampf(speed / 5, -1, 1) / (1 + absf(speed) * 0.028)
	rotate_y(-turn * delta)
	var forward := -global_transform.basis.z
	# Lateral velocity decays rapidly: predictable arcade grip without side skating.
	var desired := forward * speed
	velocity.x = lerpf(velocity.x, desired.x, 1 - exp(-12 * delta))
	velocity.z = lerpf(velocity.z, desired.z, 1 - exp(-12 * delta))
	velocity.y = -2 if is_on_floor() else velocity.y - 24 * delta
	move_and_slide()
	collided = false
	for i in get_slide_collision_count():
		if absf(get_slide_collision(i).get_normal().y) < 0.5:
			collided = true
			speed = move_toward(speed, 0, 55 * delta)
	for wheel in front_wheels:
		wheel.rotation.y = -steer_visual * 0.38
	body.rotation.z = lerpf(body.rotation.z, steer_visual * speed * 0.0017, delta * 5)

func recover(point: Vector3, heading: float = 0) -> void:
	global_position = District.nearest_road(point)
	rotation = Vector3(0, heading, 0)
	velocity = Vector3.ZERO
	speed = 0
	steer_visual = 0

# Original tapered, chamfered body sections; physics keeps the existing hull.
func profile_mesh(sections: Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	var rings: Array[PackedVector3Array] = []
	for section: Vector4 in sections:
		var w := section.x
		var y := section.y
		var f := section.z
		var r := section.w
		var c := 0.12
		rings.append(PackedVector3Array([Vector3(-w+c,y,f), Vector3(w-c,y,f), Vector3(w,y,f+c), Vector3(w,y,r-c), Vector3(w-c,y,r), Vector3(-w+c,y,r), Vector3(-w,y,r-c), Vector3(-w,y,f+c)]))
	for i in range(rings.size()-1):
		for j in 8:
			var k := (j+1)%8
			for vertex in [rings[i][j],rings[i+1][k],rings[i+1][j],rings[i][j],rings[i][k],rings[i+1][k]]:
				st.add_vertex(vertex)
	var top: PackedVector3Array = rings[-1]
	for j in range(1,7):
		for vertex in [top[0],top[j],top[j+1]]:
			st.add_vertex(vertex)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	body.add_child(mesh)
