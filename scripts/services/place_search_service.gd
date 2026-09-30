class_name PlaceSearchService
extends Node

signal loading_changed(loading: bool)
signal results_ready(results: Array)
signal search_failed(message: String)
signal place_resolved(place: Dictionary)

const AUTOCOMPLETE_URL := "https://places.googleapis.com/v1/places:autocomplete"
const DETAILS_URL := "https://places.googleapis.com/v1/places/%s"

var request: HTTPRequest
var api_key := ""
var active_city: Dictionary = {}
var offline := AddressSearch.new()
var resolving := false

func _ready() -> void:
	api_key = OS.get_environment("CITY_EXPLORER_GOOGLE_PLACES_API_KEY").strip_edges()
	request = HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(_request_completed)

func has_google_key() -> bool:
	return not api_key.is_empty()

func search(query: String, city: Dictionary) -> void:
	active_city = city
	var cleaned := query.strip_edges()
	if cleaned.length() < 2:
		results_ready.emit([])
		return
	if not has_google_key():
		results_ready.emit(_offline_results(cleaned))
		return
	request.cancel_request()
	resolving = false
	var b: Dictionary = city.search_bounds
	var body := {
		"input": cleaned,
		"languageCode": "en",
		"regionCode": "es",
		"locationRestriction": {"rectangle": {
			"low": {"latitude": b.south, "longitude": b.west},
			"high": {"latitude": b.north, "longitude": b.east},
		}},
	}
	loading_changed.emit(true)
	var error := request.request(AUTOCOMPLETE_URL, [
		"Content-Type: application/json",
		"X-Goog-Api-Key: " + api_key,
		"X-Goog-FieldMask: suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat",
	], HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		loading_changed.emit(false)
		search_failed.emit("Unable to search right now")

func resolve(place: Dictionary) -> void:
	if place.get("source", "") == "offline":
		place_resolved.emit(place)
		return
	if not has_google_key() or place.get("id", "").is_empty():
		search_failed.emit("Unable to start here")
		return
	request.cancel_request()
	resolving = true
	loading_changed.emit(true)
	var error := request.request(DETAILS_URL % place.id, [
		"X-Goog-Api-Key: " + api_key,
		"X-Goog-FieldMask: id,displayName,formattedAddress,location",
	])
	if error != OK:
		loading_changed.emit(false)
		search_failed.emit("Unable to start here")

func _request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	loading_changed.emit(false)
	if response_code < 200 or response_code >= 300:
		search_failed.emit("Unable to search right now")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		search_failed.emit("Unable to search right now")
		return
	if resolving:
		var location: Dictionary = data.get("location", {})
		if not location.has("latitude") or not location.has("longitude"):
			search_failed.emit("Unable to start here")
			return
		place_resolved.emit({
			"id": data.get("id", ""),
			"name": data.get("displayName", {}).get("text", "Selected place"),
			"address": data.get("formattedAddress", "Barcelona"),
			"latitude": float(location.latitude),
			"longitude": float(location.longitude),
			"source": "google",
		})
		return
	var results: Array = []
	for suggestion in data.get("suggestions", []):
		var prediction: Dictionary = suggestion.get("placePrediction", {})
		if prediction.is_empty():
			continue
		var structured: Dictionary = prediction.get("structuredFormat", {})
		results.append({
			"id": prediction.get("placeId", ""),
			"name": structured.get("mainText", {}).get("text", prediction.get("text", {}).get("text", "Place")),
			"address": structured.get("secondaryText", {}).get("text", "Barcelona"),
			"source": "google",
		})
	results_ready.emit(results)

func _offline_results(query: String) -> Array:
	var results: Array = []
	for record in offline.search(query, 20):
		var address := "%s %s" % [record.get("street", ""), record.get("number", "")]
		if address.strip_edges().is_empty():
			address = record.get("category", "Barcelona")
		var item: Dictionary = record.duplicate(true)
		item["address"] = address.strip_edges() + " · Barcelona"
		item["source"] = "offline"
		results.append(item)
	return results
