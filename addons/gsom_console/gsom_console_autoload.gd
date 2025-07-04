extends Node

## This is an autoload singleton, that becomes globally available when you enable the plugin.
## It holds all the common console logic and is not tied to any specific UI.


## A CVAR has been changed. You may fetch its updated value
## with `get_cvar(cvar_name)` and react to the change.
signal changed_cvar(cvar_name: String)

## A CMD was called. All listeners will receive the command name and list of args.
signal called_cmd(cmd_name: String, args: PackedStringArray)

## Console visibility toggled. In case you use the default visibility logic
## that comes with this singleton.
signal toggled(is_visible: bool)

## A log string was added. Only the latest addition is passed
## to the signal. The whole log text is available as `log_text` prop.
signal logged(rich_text: String)


const _TYPE_NAMES: Dictionary = {
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "String",
}

var COLORS_HELP: Array[String] = ["#d4fdeb", "#d4e6fd", "#fdd4e6", "#fdebd4"]
var COLOR_PRIMARY: String = "#ecf4fe"
var COLOR_SECONDARY: String = "#a3b0c7"
var COLOR_TYPE: String = "#95c1fb"
var COLOR_VALUE: String = "#f6d386"
var COLOR_INFO: String = "#a29cf5"
var COLOR_DEBUG: String = "#c3e2e5"
var COLOR_WARN: String = "#f89d2c"
var COLOR_ERROR: String = "#ff3c2c"

var CMD_SEPARATOR: String = ";"
var CMD_WAIT: String = "wait"
var EXEC_EXT: String = ".cfg"


var _log_text: String = ""
## The whole log text content. This may be also used to reset the log.
@export var log_text: String = "":
	get:
		return _log_text
	set(v):
		_log_text = v

enum TickMode {
	TICK_MODE_AUTO,
	TICK_MODE_MANUAL,
}

## The mode of calling postponed (by `wait`) commands
var tick_mode: TickMode = TickMode.TICK_MODE_AUTO

## The list of search directories to load console scripts from
var exec_paths: PackedStringArray = ['user://', 'res://']

var _is_visible: bool = false
## Current visibility status. As the UI is not directly linked to
## the singleton, this visibility flag is just for convenience. You can implement any
## other visibility logic separately and disregard this flag.
@export var is_visible: bool = false:
	get:
		return _is_visible
	set(v):
		self['show' if v else 'hide'].call()


var _history: PackedStringArray = []
## History of inserted commands. Latest command is last. Duplicate commands not stored.
@export var history: PackedStringArray = []:
	get:
		return _history


const AstParser := preload('./tools/ast_parser.gd')

var _cvars: Dictionary[String, Dictionary] = {}
var _cmds: Dictionary[String, Dictionary] = {}
var _aliases: Dictionary[String, String] = {}
var _next: Array[Array] = []
var _help_color_idx: int = 0


func _ready() -> void:
	register_cmd("help", "Display available commands and variables.")
	register_cmd("quit", "Close the application, exit to desktop.")
	register_cmd("mainscene", "Reload the main scene (as in project settings).")
	register_cmd("map", "Switch to a scene by path, or show path to the current one.")
	register_cmd("alias", "Create a named shortcut for any input text.")
	register_cmd("echo", "Print back any input.")
	register_cmd("exec", "Parse and execute commands line by line from a file.")
	register_cmd("wait", "A special command to postpone the execution by 1 tick.")
	
	called_cmd.connect(_handle_builtins)
	
	self.log(
		"Type '[b]%s[/b]' to view existing commands and variables." % [
			_color(COLOR_VALUE, "help"),
		]
	)


## Makes a new CVAR available with default value and optional help note.
func register_cvar(cvar_name: String, value: Variant, help_text: String = "") -> void:
	if _cvars.has(cvar_name) or _cmds.has(cvar_name):
		push_warning("GsomConsole.register_cvar: name '%s' already taken." % cvar_name)
		return
	
	var value_type: int = typeof(value)
	if (
			value_type != TYPE_BOOL and value_type != TYPE_INT
			and value_type != TYPE_FLOAT and value_type != TYPE_STRING
	):
		push_warning("GsomConsole.register_cvar: only bool, int, float, string supported.")
		return
	
	_cvars[cvar_name] = {
		"value": value,
		"help": help_text if !help_text.is_empty() else "[No description].",
		"hint": "",
	}
	
	set_cvar(cvar_name, value)


## Makes a new CMD available with an optional help note.
func register_cmd(cmd_name: String, help_text: String = "") -> void:
	if _cvars.has(cmd_name) or _cmds.has(cmd_name):
		push_warning("GsomConsole.register_cmd: name '%s' already taken." % cmd_name)
		return
	
	_cmds[cmd_name] = {
		"help": help_text if !help_text.is_empty() else "[No description].",
	}


## Add or remove an alias.
## CVARs and CMDs take precedence - can't override with alias.
## Empty `alias_text` will remove the existing alias.
func alias(alias_name: String, alias_text: String = "") -> void:
	if _cvars.has(alias_name) or _cmds.has(alias_name):
		push_warning("GsomConsole.alias: name '%s' already taken." % alias_name)
		return
	
	if alias_text:
		_aliases[alias_name] = alias_text
	else:
		_aliases.erase(alias_name)


## Manually call a command, as if the call was parsed from user input.
func call_cmd(cmd_name: String, args: PackedStringArray) -> void:
	if !_cmds.has(cmd_name):
		push_warning("GsomConsole.call_cmd: CMD '%s' does not exist." % cmd_name)
		return
	
	called_cmd.emit(cmd_name, args)


# Assign new value to the CVAR.
func set_cvar(cvar_name: String, value: Variant) -> void:
	if !_cvars.has(cvar_name):
		push_warning("GsomConsole.set_cvar: CVAR %s has not been registered." % cvar_name)
		return
	
	var adjusted: Variant = _adjust_type(_cvars[cvar_name].value, str(value))
	
	_cvars[cvar_name].value = adjusted
	var type_value: int = typeof(adjusted)
	var type_name: String = _TYPE_NAMES[type_value]
	var hint: String = "%s %s %s" % [
		_color(COLOR_SECONDARY, ":"),
		_color(COLOR_TYPE, type_name),
		_color(COLOR_VALUE, str(adjusted)),
	]
	_cvars[cvar_name].hint = hint
	
	changed_cvar.emit(cvar_name)


## Inspect the current CVAR value.
func get_cvar(cvar_name: String) -> Variant:
	if !_cvars.has(cvar_name):
		push_warning("GsomConsole.get_cvar: CVAR %s has not been registered." % cvar_name)
		return 0
	
	return _cvars[cvar_name].value


## List all CVAR names.
func list_cvars() -> Array[String]:
	return _cvars.keys()


## Check if there is a CVAR with given name.
func has_cvar(cvar_name: String) -> bool:
	return _cvars.has(cvar_name)


## Check if there is a CMD with given name
func has_cmd(cmd_name: String) -> bool:
	return _cmds.has(cmd_name)


## Check if there is an ALIAS with given name
func has_alias(alias_name: String) -> bool:
	return _aliases.has(alias_name)


## Get a list of CVAR and CMD names that start with the given `text`.
func get_matches(text: String) -> PackedStringArray:
	var matches: PackedStringArray = []
	
	if !text:
		return matches
	
	for k: String in _cvars:
		if k.begins_with(text):
			matches.append(k)
	
	for k: String in _cmds:
		if k.begins_with(text):
			matches.append(k)
	
	return matches


## Set `is_visible` to `false` if it was `true`. Only emits `on_toggle` if indeed changed.
func hide() -> void:
	if !_is_visible:
		return
	
	_is_visible = false
	toggled.emit(false)


## Set `is_visible` to `true` if it was `false`. Only emits `on_toggle` if indeed changed.
func show() -> void:
	if _is_visible:
		return
	
	_is_visible = true
	toggled.emit(true)


## Changes the `is_visible` value to the opposite and emits `on_toggle`.
func toggle() -> void:
	_is_visible = !_is_visible
	toggled.emit(_is_visible)


## Submit user input for parsing.
## cmd arg1 arg2
## cmd1 arg1; cmd2
## cmd1; wait; cmd2
## cmd1 "text; text"; cmd2
func submit(expression: String, track_history: bool = true) -> void:
	var parsed: AstParser = AstParser.new(expression)
	if parsed.error:
		self.error("Syntax error. `%s`" % [parsed.error])
		return
	
	if track_history:
		_history_push(expression.strip_edges())
	
	_submit_ast(parsed.ast)


func _submit_ast(ast: Array[PackedStringArray]) -> void:
	for i: int in ast.size():
		var part: PackedStringArray = ast[i]
		if part[0] == CMD_WAIT:
			_next.append(ast.slice(i + 1))
			break
			
		_submit_part(part)


func _try_create_alias(ast_part: PackedStringArray) -> bool:
	if ast_part[0] != "alias":
		return false
	
	if ast_part.size() == 1:
		var result: PackedStringArray = []
		_append_alias_list(result)
		self.log("".join(result)) # using `self` to avoid name collision
		return true
	
	if ast_part.size() == 2:
		alias(ast_part[1])
		return true
	
	alias(ast_part[1], " ".join(ast_part.slice(2)))
	return true


func _submit_part(ast_part: PackedStringArray) -> bool:
	if _try_create_alias(ast_part):
		return false
	
	var g0: String = ast_part[0]
	
	if has_alias(g0):
		submit(_aliases[g0], false)
		return false
	
	if has_cmd(g0):
		call_cmd(g0, ast_part.slice(1))
		return false
	
	if (ast_part.size() == 1 or ast_part.size() == 2) and has_cvar(g0):
		if ast_part.size() == 2:
			var g1: String = ast_part[1]
			set_cvar(g0, g1)
		
		var result: Variant = get_cvar(g0)
		var type_value: int = typeof(result)
		var type_name: String = _TYPE_NAMES[type_value]
		self.log("%s%s%s %s" % [
				_color(COLOR_PRIMARY, g0),
				_color(COLOR_SECONDARY, ":"),
				_color(COLOR_TYPE, type_name),
				_color(COLOR_VALUE, str(result)),
		])
		return false
	
	error("Unrecognized command `%s`." % [" ".join(ast_part)])
	return false


## Appends `msg` to `log_text` and emits `on_log`.
func log(msg: String) -> void:
	_log_text += msg + "\n"
	logged.emit(msg)


## Wraps `msg` with color BBCode and calls `log`.
func info(msg: String) -> void:
	self.log(_color(COLOR_INFO, "[b]info:[/b] %s" % msg))


## Wraps `msg` with color BBCode and calls `log`.
func debug(msg: String) -> void:
	self.log(_color(COLOR_DEBUG, "[b]dbg:[/b] %s" % msg))


## Wraps `msg` with color BBCode and calls `log`.
func warn(msg: String) -> void:
	self.log(_color(COLOR_WARN, "[b]warn:[/b] %s" % msg))


## Wraps `msg` with color BBCode and calls `log`.
func error(msg: String) -> void:
	self.log(_color(COLOR_ERROR, "[b]err:[/b] %s" % msg))


## Calls the enqueued by "wait" commands.
## By default it is called automatically every frame.
## Only required to call manually if `tick_mode` is manual.
## There is no harm calling it manually either way.
func tick() -> void:
	if !_next.size():
		return
	
	var _prev = _next
	_next = []
	
	for ast: Array[PackedStringArray] in _prev:
		_submit_ast(ast)


func _process(_delta: float) -> void:
	if tick_mode == TickMode.TICK_MODE_AUTO:
		tick()


# "wait" and "alias" are non-commands, handled separately in `submit`
func _handle_builtins(cmd_name: String, args: PackedStringArray) -> void:
	if cmd_name == "echo":
		_cmd_echo(args)
	if cmd_name == "exec":
		_cmd_exec(args)
	if cmd_name == "help":
		_cmd_help(args)
	elif cmd_name == "quit":
		get_tree().quit()
	elif cmd_name == "map":
		_cmd_map(args)
	elif cmd_name == "mainscene":
		_cmd_map([ProjectSettings.get_setting("application/run/main_scene")])


func _color(color: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


func _adjust_type(old_value: Variant, new_value: String) -> Variant:
	var value_type = typeof(old_value)
	if value_type == TYPE_BOOL:
		return new_value == "true" or new_value == "1"
	elif value_type == TYPE_INT:
		return int(new_value)
	elif value_type == TYPE_FLOAT:
		return float(new_value)
	elif value_type == TYPE_STRING:
		return new_value
	
	push_warning("GsomConsole.set_cvar: only bool, int, float, string supported.")
	return old_value


func _get_help_color() -> String:
	var color: String = COLORS_HELP[_help_color_idx % COLORS_HELP.size()]
	_help_color_idx = _help_color_idx + 1
	return color


func _cmd_map(args: PackedStringArray) -> void:
	if !args.size():
		self.log(
			"The current scene is '[b]%s[/b]'." % [
				_color(COLOR_VALUE, get_tree().current_scene.scene_file_path),
			]
		)
		return
	
	# `map [name]` syntax below
	var map_name: String = args[0]
	if !ResourceLoader.exists(map_name):
		map_name += ".tscn"
	if !ResourceLoader.exists(map_name):
		error(
			"Scene '[b]%s[/b]' doesn't exist." % [
				_color(COLOR_VALUE, args[0]),
			]
		)
		return
	
	self.log(
		"Changing scene to '[b]%s[/b]'..." % [
			_color(COLOR_VALUE, map_name),
		]
	)
	
	get_tree().change_scene_to_file(map_name)
	GsomConsole.hide()


func _cmd_echo(args: PackedStringArray) -> void:
	if !args.size():
		return
	self.log(" ".join(args))


func _cmd_exec(args: PackedStringArray) -> void:
	if !args.size():
		self.log(
			"Syntax: 'exec [b]%s[/b]'." % [
				_color(COLOR_VALUE, "file[%s]" % EXEC_EXT),
			]
		)
		var result: PackedStringArray = []
		_append_exec_path_list(result)
		self.log("".join(result)) # using `self` to avoid name collision
		return
	
	var exec_name: String = args[0]
	_search_and_exec(exec_name)


## Function receives a console script name - with or without extension (`EXEC_EXT`).
## Tries to locate the file in `exec_paths`.
## Each directory is tried first without the file extension, then with extension.
## As soon as the first file match found, the file is read and executed, the search stops.
## The file execution is performed by splitting it line-by line.
## Then non-empty (and non-whitespace) lines are fed to the `submit(text)` method.
func _search_and_exec(exec_name: String) -> void:
	var file: FileAccess = null
	
	for dir_path in exec_paths:
		file = FileAccess.open(dir_path + exec_name, FileAccess.READ)
		if file:
			break
		file = FileAccess.open(dir_path + exec_name + EXEC_EXT, FileAccess.READ)
		if file:
			break
	
	if !file:
		error("Script '[b]%s[/b]' doesn't exist." % [_color(COLOR_VALUE, exec_name)])
		return

	self.log("Executing script '[b]%s[/b]'..." % [_color(COLOR_VALUE, exec_name)])
	while !file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if !line.is_empty():
			submit(line, false)
	file.close()


func _cmd_help(args: PackedStringArray) -> void:
	var i: int = 0
	var result: PackedStringArray = []
	
	# `help [name1, name2, ...]` syntax
	if args.size():
		for arg: String in args:
			var color: String = _get_help_color()
			if _cmds.has(arg):
				result.append(_color(color, "[b]%s[/b] - %s" % [arg, _cmds[arg].help]))
				result.append("\n")
			elif _cvars.has(arg):
				result.append(_color(color, "[b]%s[/b] - %s" % [arg, _cvars[arg].help]))
				result.append("\n")
			else:
				result.append(_color(COLOR_ERROR, "[b]%s[/b] - No such command/variable." % arg))
				result.append("\n")
		
		self.log("".join(PackedStringArray(result)))
		return
	
	_append_cvar_list(result)
	_append_cmd_list(result)
	_append_alias_list(result)
	
	self.log("".join(result)) # using `self` to avoid name collision


# Mutates `dest` by adding CMDs info
func _append_cvar_list(dest: PackedStringArray) -> void:
	if !_cvars.size():
		dest.append("There are no variables, yet.\n")
		return
	
	dest.append("Available variables:\n")
	
	for key: String in _cvars:
		var color: String = _get_help_color()
		dest.append(_color(color, "[b]%s[/b] - %s" % [key, _cvars[key].help]))
		dest.append("\n")


# Mutates `dest` by adding CMDs info
func _append_cmd_list(dest: PackedStringArray) -> void:
	if !_cmds.size():
		dest.append("There are no commands, yet.\n")
		return
	
	dest.append("Available commands:\n")
	
	for key: String in _cmds:
		var color: String = _get_help_color()
		dest.append(_color(color, "[b]%s[/b] - %s" % [key, _cmds[key].help]))
		dest.append("\n")


# Mutates `dest` by adding ALIASes info
func _append_alias_list(dest: PackedStringArray) -> void:
	if !_aliases.size():
		dest.append("There are no aliases, yet.\n")
		return
	
	dest.append("Available aliases:\n")
	
	for key: String in _aliases:
		var color: String = _get_help_color()
		dest.append(_color(color, "[b]%s[/b] - %s" % [key, _aliases[key]]))
		dest.append("\n")


# Mutates `dest` by adding exec paths info
func _append_exec_path_list(dest: PackedStringArray) -> void:
	if !exec_paths.size():
		dest.append("There are no exec paths, yet.\n")
		return
	
	dest.append("Registered exec paths:\n")
	
	for path: String in exec_paths:
		var color: String = _get_help_color()
		dest.append(_color(color, "\t%s\n" % path))


func _history_push(expression: String) -> void:
	var history_len: int = _history.size()
	if history_len and _history[history_len - 1] == expression:
		return
	
	_history.append(expression)
