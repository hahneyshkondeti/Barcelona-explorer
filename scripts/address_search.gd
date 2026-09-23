class_name AddressSearch
extends RefCounted

var streets: Dictionary = {}
var normalized_streets: Dictionary = {}
var tiles: Dictionary = {}

static func normalize(value: String) -> String:
	var text := value.to_lower()
	for pair in [["àáâä", "a"], ["èéêë", "e"], ["ìíîï", "i"], ["òóôö", "o"], ["ùúûü", "u"], ["ç", "c"], ["ñ", "n"]]:
		for letter in pair[0]: text = text.replace(letter, pair[1])
	for mark in ["·", ",", ".", "'", "’", "-", "/"]: text = text.replace(mark, " ")
	return text

static func words_match(query: Array[String], text: String, fuzzy: bool = false) -> bool:
	var words := text.split(" ", false)
	for token in query:
		if token in ["de", "del", "la", "el", "carrer", "calle"]: continue
		var found := token in text
		if not found and fuzzy and token.length() >= 5:
			for word in words:
				if token.similarity(word) >= 0.7: found = true; break
		if not found: return false
	return true

static func number_matches(query: String, number: String) -> bool:
	if query.is_empty(): return true
	if query == number.to_lower(): return true
	var parts := number.split("-")
	if query.is_valid_int() and parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return int(query) >= mini(int(parts[0]), int(parts[1])) and int(query) <= maxi(int(parts[0]), int(parts[1]))
	return false

func search(query: String, limit: int = 300) -> Array:
	if streets.is_empty():
		streets = JSON.parse_string(FileAccess.get_file_as_string("res://data/city/address_index.json"))
		for street in streets: normalized_streets[street] = normalize(street)
	var tokens: Array[String] = []
	var number := ""
	for token in normalize(query).split(" ", false):
		if token.is_valid_int(): number = token
		else: tokens.append(token)
	var results: Array = []
	if not tokens.is_empty():
		# Exact street matches first, then tolerant spelling suggestions.
		for fuzzy in [false, true]:
			for street in streets:
				if not words_match(tokens, normalized_streets[street], fuzzy): continue
				if fuzzy and words_match(tokens, normalized_streets[street]): continue
				for key in streets[street]:
					if not tiles.has(key):
						if tiles.size() >= 8: tiles.erase(tiles.keys()[0])
						tiles[key] = JSON.parse_string(FileAccess.get_file_as_string(District.DATA.tiles[key])).addresses
					for record in tiles[key]:
						if record.street != street or not number_matches(number, record.number): continue
						var item: Dictionary = record.duplicate()
						item.name = "%s %s" % [street, record.number]
						item.category = "Recorded address range" if "-" in record.number else "Recorded address"
						item.check_date = ""
						item.suggested = fuzzy
						results.append(item)
						if results.size() >= limit: return results
	for item in District.DATA.places:
		var text := normalize("%s %s %s" % [item.name, item.street, item.number])
		if words_match(tokens, text) and (number.is_empty() or number_matches(number, item.number)):
			results.append(item)
			if results.size() >= limit: break
	return results
