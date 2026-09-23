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
	WorldBuilder.box(body, Vector3(1.85, 0.65, 3.65), Vector3(0, 0.42, 0), Color("e76e45"))
	WorldBuilder.box(body, Vector3(1.5, 0.65, 1.85), Vector3(0, 1.03, 0.15), Color("f6d7a6"))
	WorldBuilder.box(body, Vector3(1.38, 0.46, 1.9), Vector3(0, 1.05, 0.14), Color("284b58"))
	WorldBuilder.box(body, Vector3(1.52, 0.12, 1.9), Vector3(0, 1.39, 0.14), Color("f6d7a6"))
	for x in [-0.96, 0.96]:
		for z in [-1.13, 1.13]:
			var pivot := Node3D.new()
			body.add_child(pivot)
			pivot.position = Vector3(x, 0.29, z)
			var wheel := WorldBuilder.cylinder(pivot, 0.39, 0.26, Vector3.ZERO, Color("23333b"))
			wheel.rotation.z = PI / 2
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
