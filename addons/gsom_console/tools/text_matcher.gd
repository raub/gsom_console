extends RefCounted

## Finds "similar" commands (for hints or built-in "find x").
## It uses a variation of score-based fuzzy search.

## Read-only match result
var matched: PackedStringArray:
	get:
		return __matched

# Internal storage
var __matched: PackedStringArray = []

class ScoredToken:
	var token: String
	var score: int
	
	func _init(t: String, s: int) -> void:
		token = t
		score = s

func _init(text: String, available: PackedStringArray) -> void:
	var query := text.to_lower()
	var scored: Array[ScoredToken] = []
	
	for token: String in available:
		var lower := token.to_lower()
		var score: int = __get_match_score(query, lower)
		if score >= 200:
			scored.append(ScoredToken.new(token, score))
	
	scored.sort_custom(__sort_descending_by_score)
	
	for entry: ScoredToken in scored:
		var token: String = entry.token
		__matched.append(token)


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
	return absi(query.length() - target.length()) * 20


func __sequence_match_score(query: String, target: String) -> int:
	var index: int = 0
	for letter: String in query:
		index = target.find(letter, index)
		if index == -1:
			return -1
		index += 1
	return 400 - __length_penalty(query, target)


static func __sort_descending_by_score(a: ScoredToken, b: ScoredToken) -> bool:
	return a.score > b.score


func __levenshtein(a: String, b: String) -> int:
	var len_a := a.length()
	var len_b := b.length()
	if len_a == 0:
		return len_b
	if len_b == 0:
		return len_a

	var matrix: Array[Array] = []
	for i: int in len_a + 1:
		matrix.append([])
		for j: int in len_b + 1:
			matrix[i].append(0)

	for i: int in len_a + 1:
		matrix[i][0] = i
	for j: int in len_b + 1:
		matrix[0][j] = j

	for i: int in range(1, len_a + 1):
		for j: int in range(1, len_b + 1):
			var cost: int = 0 if a[i - 1] == b[j - 1] else 1
			matrix[i][j] = min(
				matrix[i - 1][j] + 1,
				matrix[i][j - 1] + 1,
				matrix[i - 1][j - 1] + cost
			)

	return matrix[len_a][len_b]


func __longest_common_prefix(a: String, b: String) -> String:
	var min_len := mini(a.length(), b.length())
	var i: int = 0
	while i < min_len and a[i] == b[i]:
		i += 1
	return a.substr(0, i)
