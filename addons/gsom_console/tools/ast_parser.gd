extends RefCounted

## Parsed abstract syntax tree result.
var ast: Array[PackedStringArray]:
	get: return __ast.duplicate()

## Empty string means no error; otherwise contains description of the parse error.
var error: String:
	get: return __error

# Internal backing storage
var __ast: Array[PackedStringArray] = []
var __error: String = ""

## Parses the command line string into AST on creation.
func _init(input: String) -> void:
	input = input.strip_edges()
	if input.is_empty():
		return

	# Initial validation: first char must be a valid command name start
	if !__is_valid_command_start(input[0]):
		__error = "Command must start with a letter or underscore."
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
						__ast.append(current_command)
						current_command = []
			_:
				current_token += c
		i += 1

	# Final flush
	if inside_quotes:
		__error = "Unterminated quoted string."
		return

	if current_token != "":
		current_command.append(current_token)
	if current_command.size() > 0:
		__ast.append(current_command)
	
	# Post-validation: each command must start with a valid identifier
	for command in __ast:
		if command.is_empty() or !__is_valid_command_start(command[0][0]):
			__error = "Command name must begin with a letter or underscore."
			__ast.clear()
			return


## Returns true if the character is a valid starting character for a command name.
static func __is_valid_command_start(c: String) -> bool:
	var r := RegEx.new()
	r.compile("[a-z_+-]")
	return !!r.search(c.to_lower())
