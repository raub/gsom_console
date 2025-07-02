extends RefCounted

## Parsed abstract syntax tree result.
var ast: Array[PackedStringArray]:
	get: return _ast.duplicate()

## Empty string means no error; otherwise contains description of the parse error.
var error: String:
	get: return _error

# Internal backing storage
var _ast: Array[PackedStringArray] = []
var _error: String = ""

## Parses the command line string into AST on creation.
func _init(input: String) -> void:
	input = input.strip_edges().to_lower()
	if input.is_empty():
		return

	# Initial validation: first char must be a valid command name start
	if !_is_valid_command_start(input[0]):
		_error = "Command must start with a letter or underscore."
		return

	var current_command: PackedStringArray = []
	var current_token := ""
	var inside_quotes := false
	var i := 0
	var length := input.length()

	while i < length:
		var c := input[i]

		match c:
			'"':
				if inside_quotes:
					inside_quotes = false
					current_command.append(current_token)
					current_token = ""
				else:
					if current_token != "":
						current_command.append(current_token)
						current_token = ""
					inside_quotes = true
			' ', '\t':
				if inside_quotes:
					current_token += c
				elif current_token != "":
					current_command.append(current_token)
					current_token = ""
			GsomConsole.CMD_SEPARATOR:
				if inside_quotes:
					current_token += c
				else:
					if current_token != "":
						current_command.append(current_token)
						current_token = ""
					if current_command.size() > 0:
						_ast.append(current_command)
						current_command = []
			_:
				current_token += c
		i += 1

	# Final flush
	if inside_quotes:
		_error = "Unterminated quoted string."
		return

	if current_token != "":
		current_command.append(current_token)
	if current_command.size() > 0:
		_ast.append(current_command)

	# Post-validation: each command must start with a valid identifier
	for command in _ast:
		if command.is_empty() or !_is_valid_command_start(command[0][0]):
			_error = "Command name must begin with a letter or underscore."
			_ast.clear()
			return


## Returns true if the character is a valid starting character for a command name.
static func _is_valid_command_start(c: String) -> bool:
	var r := RegEx.new()
	r.compile("[a-z0-9_]")
	return !!r.search(c)
