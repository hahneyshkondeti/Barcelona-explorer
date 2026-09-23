extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func simulate(car: TouringCar, seconds: float, hz: int = 60) -> float:
	var distance := 0.0
	for i in roundi(seconds * hz):
		car.update_handling(1.0 / hz)
		distance += car.speed / hz
	return distance

func fresh() -> TouringCar:
	var car := TouringCar.new()
	car.controls = DriveInput.new()
	return car

func dispose(car: TouringCar) -> void:
	car.controls.free()
	car.free()

func _initialize() -> void:
	var car := fresh()
	car.controls.steering = 1
	simulate(car, 1)
	check(car.yaw_rate == 0, "Steering at rest cannot rotate the car")
	car.controls.throttle = 1
	car.update_handling(1.0 / 60)
	check(car.speed > 0 and car.speed < 0.04, "Throttle ramps smoothly from rest")
	simulate(car, 1)
	check(car.yaw_rate > 0.4 and car.steering_angle > 0.3, "Slow-speed steering allows tight city turns")
	simulate(car, 10)
	check(absf(car.speed * car.yaw_rate) <= TouringCar.MAX_LATERAL_ACCEL + 0.1, "Full steering at speed stays within lateral acceleration budget")
	car.controls.steering = 0
	simulate(car, 0.6)
	check(absf(car.yaw_rate) < 0.025, "Releasing steering settles back to straight driving")
	car.controls.throttle = 0
	car.controls.brake = 1
	var distance := 0.0
	var ticks := 0
	while car.speed > 0 and ticks < 180:
		distance += simulate(car, 1.0 / 60)
		ticks += 1
	check(car.speed == 0 and distance < 16, "Full braking stops from cruising speed within 16 metres")
	simulate(car, 0.2)
	check(car.speed == 0, "Holding brake briefly after stopping does not reverse")
	simulate(car, 1.5)
	check(car.speed == -TouringCar.REVERSE_SPEED, "Continued brake hold engages bounded reverse")
	car.controls.steering = 1
	simulate(car, 0.5)
	check(car.yaw_rate < 0, "Reverse steering turns in the opposite direction")
	car.controls.throttle = 1
	simulate(car, 1)
	check(car.speed == 0, "Both pedals stop the car without changing direction")
	dispose(car)
	var results: Array[Vector2] = []
	for hz in [30, 60, 120]:
		car = fresh()
		car.controls.throttle = 1
		var travelled := simulate(car, 3, hz)
		results.append(Vector2(car.speed, travelled))
		dispose(car)
	check(absf(results[0].x - results[2].x) < 0.2 and absf(results[0].y - results[2].y) < 0.7, "Handling remains consistent across 30/60/120 Hz steps")
	print("RESULT: %d handling checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
