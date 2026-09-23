class_name Landmarks
extends Node

signal arrived
var car: TouringCar
var discovered := false
var inside := false
var cooldown := 0.0

func _process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	if car == null or car.paused:
		return
	var near_destination := car.global_position.distance_to(District.DESTINATION) < 13
	if near_destination and absf(car.speed) < 2 and not inside and cooldown == 0:
		inside = true
		discovered = true
		arrived.emit()
	elif not near_destination:
		inside = false

func dismiss() -> void:
	cooldown = 4
