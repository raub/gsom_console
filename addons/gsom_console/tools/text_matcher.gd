extends RefCounted

## Read-only match result
var matched: PackedStringArray:
	get:
		return __matched

# Internal storage
var __matched: PackedStringArray = []

func _init(text: String, available: PackedStringArray) -> void:
	var query := text.to_lower()
	var scored: Array[Dictionary] = []

	for token in available:
		var lower := token.to_lower()
		var score := __get_match_score(query, lower)
		if score >= 200:
			scored.append({ "token": token, "score": score })

	scored.sort_custom(__sort_descending_by_score)

	for entry in scored:
		__matched.append(entry["token"])


func __get_match_score(query: String, target: String) -> int:
	if query == target:
		return 1000
	elif target.begins_with(query):
		return 800 - __length_penalty(query, target)
	elif query in target:
		return 600 - __length_penalty(query, target)

	var seq_score := __sequence_match_score(query, target)
	if seq_score >= 0:
		return seq_score

	var lev := __levenshtein(query, target)
	if lev <= 3:
		var common_prefix := __longest_common_prefix(query, target)
		if common_prefix.length() >= 1:
			var base := 500 - lev * 60 - __length_penalty(query, target)
			if base >= 200:
				return base

	return -1


func __length_penalty(query: String, target: String) -> int:
	return abs(query.length() - target.length()) * 20


func __sequence_match_score(query: String, target: String) -> int:
	var index := 0
	for char in query:
		index = target.find(char, index)
		if index == -1:
			return -1
		index += 1
	return 400 - __length_penalty(query, target)


static func __sort_descending_by_score(a: Dictionary, b: Dictionary) -> bool:
	return a["score"] > b["score"]


func __levenshtein(a: String, b: String) -> int:
	var len_a := a.length()
	var len_b := b.length()
	if len_a == 0:
		return len_b
	if len_b == 0:
		return len_a

	var matrix := []
	for i in len_a + 1:
		matrix.append([])
		for j in len_b + 1:
			matrix[i].append(0)

	for i in len_a + 1:
		matrix[i][0] = i
	for j in len_b + 1:
		matrix[0][j] = j

	for i in range(1, len_a + 1):
		for j in range(1, len_b + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			matrix[i][j] = min(
				matrix[i - 1][j] + 1,
				matrix[i][j - 1] + 1,
				matrix[i - 1][j - 1] + cost
			)

	return matrix[len_a][len_b]


func __longest_common_prefix(a: String, b: String) -> String:
	var min_len := min(a.length(), b.length())
	var i := 0
	while i < min_len and a[i] == b[i]:
		i += 1
	return a.substr(0, i)
