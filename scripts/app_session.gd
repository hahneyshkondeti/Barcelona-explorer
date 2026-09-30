class_name AppSession
extends RefCounted

enum Screen { HOME, CITY, LOCATION, VEHICLE, EXPLORING, PAUSED, SETTINGS }

var screen := Screen.HOME
var mode := "explore"
var selected_city: Dictionary = AppCatalog.city(AppCatalog.DEFAULT_CITY_ID)
var selected_place: Dictionary = {}
var selected_vehicle: Dictionary = AppCatalog.vehicle(AppCatalog.DEFAULT_VEHICLE_ID)
var selected_point := Vector3.INF
var theme := "dark"

func select_city(id: String) -> void:
	selected_city = AppCatalog.city(id)

func select_vehicle(id: String) -> void:
	selected_vehicle = AppCatalog.vehicle(id)
