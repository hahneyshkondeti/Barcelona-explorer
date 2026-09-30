class_name AppCatalog
extends RefCounted

const DEFAULT_CITY_ID := "barcelona"
const DEFAULT_VEHICLE_ID := "touring_car"

static func cities() -> Array[Dictionary]:
	return [{
		"id": "barcelona",
		"name": "Barcelona",
		"country": "Spain",
		"latitude": 41.3874,
		"longitude": 2.1686,
		"search_bounds": {
			"south": 41.3170354,
			"west": 2.0524977,
			"north": 41.4679135,
			"east": 2.2283555,
		},
		"supported": true,
		"map_id": District.ID,
		"preview_image": "",
	}]

static func vehicles() -> Array[Dictionary]:
	return [{
		"id": "touring_car",
		"display_name": "City Touring Car",
		"model": "TouringCar",
		"preview_image": "",
		"available": true,
		"metadata": {"style": "Responsive electric touring car"},
	}]

static func city(id: String) -> Dictionary:
	for item in cities():
		if item.id == id:
			return item
	return cities()[0]

static func vehicle(id: String) -> Dictionary:
	for item in vehicles():
		if item.id == id:
			return item
	return vehicles()[0]
