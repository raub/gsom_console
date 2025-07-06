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


const __TYPE_NAMES: Dictionary = {
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


var __log_text: String = ""
## The whole log text content. This may be also used to reset the log.
@export var log_text: String = "":
	get:
		return __log_text
	set(v):
		__log_text = v

enum TickMode {
	TICK_MODE_AUTO,
	TICK_MODE_MANUAL,
}

## The mode of calling postponed (by `wait`) commands
var tick_mode: TickMode = TickMode.TICK_MODE_AUTO

## The list of search directories to load console scripts from
var exec_paths: PackedStringArray = ['user://', 'res://']

var __is_visible: bool = false
## Current visibility status. As the UI is not directly linked to
## the singleton, this visibility flag is just for convenience. You can implement any
## other visibility logic separately and disregard this flag.
@export var is_visible: bool = false:
	get:
		return __is_visible
	set(v):
		self['show' if v else 'hide'].call()


var __history: PackedStringArray = []
## History of inserted commands. Latest command is last. Duplicate commands not stored.
@export var history: PackedStringArray = []:
	get:
		return __history


const CommonUi := preload('./tools/common_ui.gd')
const AstParser := preload('./tools/ast_parser.gd')

var __cvars: Dictionary[String, Dictionary] = {}
var __cmds: Dictionary[String, Dictionary] = {}
var __aliases: Dictionary[String, String] = {}
var __next: Array[Array] = []
var __help_color_idx: int = 0


func _ready() -> void:
	register_cmd("help", "Display available commands and variables.")
	register_cmd("quit", "Close the application, exit to desktop.")
	register_cmd("mainscene", "Reload the main scene (as in project settings).")
	register_cmd("map", "Switch to a scene by path, or show path to the current one.")
	register_cmd("alias", "Create a named shortcut for any input text.")
	register_cmd("echo", "Print back any input.")
	register_cmd("exec", "Parse and execute commands line by line from a file.")
	register_cmd("wait", "A special command to postpone the execution by 1 tick.")
	
	called_cmd.connect(__handle_builtins)
	
	self.log(
		"Type '[b]%s[/b]' to view existing commands and variables." % [
			__color(COLOR_VALUE, "help"),
		]
	)


## Makes a new CVAR available with default value and optional help note.
func register_cvar(cvar_name: String, value: Variant, help_text: String = "") -> void:
	if __cvars.has(cvar_name) or __cmds.has(cvar_name):
		push_warning("GsomConsole.register_cvar: name '%s' already taken." % cvar_name)
		return
	
	var value_type: int = typeof(value)
	if (
			value_type != TYPE_BOOL and value_type != TYPE_INT
			and value_type != TYPE_FLOAT and value_type != TYPE_STRING
	):
		push_warning("GsomConsole.register_cvar: only bool, int, float, string supported.")
		return
	
	__cvars[cvar_name] = {
		"value": value,
		"help": help_text if !help_text.is_empty() else "[No description].",
		"hint": "",
	}
	
	set_cvar(cvar_name, value)


## Makes a new CMD available with an optional help note.
func register_cmd(cmd_name: String, help_text: String = "") -> void:
	if __cvars.has(cmd_name) or __cmds.has(cmd_name):
		push_warning("GsomConsole.register_cmd: name '%s' already taken." % cmd_name)
		return
	
	__cmds[cmd_name] = {
		"help": help_text if !help_text.is_empty() else "[No description].",
	}


## Add or remove an alias.
## CVARs and CMDs take precedence - can't override with alias.
## Empty `alias_text` will remove the existing alias.
func alias(alias_name: String, alias_text: String = "") -> void:
	alias_name = alias_name.strip_edges().to_lower()
	
	if __cvars.has(alias_name) or __cmds.has(alias_name):
		self.warn("Alias name '%s' not available." % alias_name)
		return
	
	if alias_text:
		__aliases[alias_name] = alias_text
	else:
		__aliases.erase(alias_name)


## Manually call a command, as if the call was parsed from user input.
func call_cmd(cmd_name: String, args: PackedStringArray) -> void:
	if !__cmds.has(cmd_name):
		push_warning("GsomConsole.call_cmd: CMD '%s' does not exist." % cmd_name)
		return
	
	called_cmd.emit(cmd_name, args)


# Assign new value to the CVAR.
func set_cvar(cvar_name: String, value: Variant) -> void:
	if !__cvars.has(cvar_name):
		push_warning("GsomConsole.set_cvar: CVAR %s has not been registered." % cvar_name)
		return
	
	var adjusted: Variant = __adjust_type(__cvars[cvar_name].value, str(value))
	
	__cvars[cvar_name].value = adjusted
	var type_value: int = typeof(adjusted)
	var type_name: String = __TYPE_NAMES[type_value]
	var hint: String = "%s %s %s" % [
		__color(COLOR_SECONDARY, ":"),
		__color(COLOR_TYPE, type_name),
		__color(COLOR_VALUE, str(adjusted)),
	]
	__cvars[cvar_name].hint = hint
	
	changed_cvar.emit(cvar_name)


## Inspect the current CVAR value.
func get_cvar(cvar_name: String) -> Variant:
	if !__cvars.has(cvar_name):
		push_warning("GsomConsole.get_cvar: CVAR %s has not been registered." % cvar_name)
		return 0
	
	return __cvars[cvar_name].value


## List all CVAR names.
func list_cvars() -> Array[String]:
	return __cvars.keys()


## Check if there is a CVAR with given name.
func has_cvar(cvar_name: String) -> bool:
	return __cvars.has(cvar_name)


## Check if there is a CMD with given name
func has_cmd(cmd_name: String) -> bool:
	return __cmds.has(cmd_name)


## Check if there is an ALIAS with given name
func has_alias(alias_name: String) -> bool:
	return __aliases.has(alias_name)


## Get a list of CVAR and CMD names that start with the given `text`.
func get_matches(text: String) -> PackedStringArray:
	var matches: PackedStringArray = []
	
	if !text:
		return matches
	
	for k: String in __cvars:
		if k.begins_with(text):
			matches.append(k)
	
	for k: String in __cmds:
		if k.begins_with(text):
			matches.append(k)
	
	return matches


## Set `is_visible` to `false` if it was `true`. Only emits `on_toggle` if indeed changed.
func hide() -> void:
	if !__is_visible:
		return
	
	__is_visible = false
	toggled.emit(false)


## Set `is_visible` to `true` if it was `false`. Only emits `on_toggle` if indeed changed.
func show() -> void:
	if __is_visible:
		return
	
	__is_visible = true
	toggled.emit(true)


## Changes the `is_visible` value to the opposite and emits `on_toggle`.
func toggle() -> void:
	__is_visible = !__is_visible
	toggled.emit(__is_visible)


## Submit user input for parsing.
## cmd arg1 arg2
## cmd1 arg1; cmd2
## cmd1; wait; cmd2
## cmd1 "text; text"; cmd2
func submit(expression: String, track__history: bool = true) -> void:
	var parsed: AstParser = AstParser.new(expression)
	if parsed.error:
		self.error("Syntax error. `%s`" % [parsed.error])
		return
	
	if track__history:
		__history_push(expression.strip_edges())
	
	__submit_ast(parsed.ast)


func __submit_ast(ast: Array[PackedStringArray]) -> void:
	for i: int in ast.size():
		var part: PackedStringArray = ast[i]
		if part[0] == CMD_WAIT:
			__next.append(ast.slice(i + 1))
			break
			
		__submit_part(part)


func __try_create_alias(ast_part: PackedStringArray) -> bool:
	if ast_part[0] != "alias":
		return false
	
	if ast_part.size() == 1:
		var result: PackedStringArray = []
		__append_alias_list(result)
		self.log("".join(result)) # using `self` to avoid name collision
		return true
	
	if ast_part.size() == 2:
		alias(ast_part[1])
		return true
	
	alias(ast_part[1], " ".join(ast_part.slice(2)))
	return true


func __submit_part(ast_part: PackedStringArray) -> bool:
	if __try_create_alias(ast_part):
		return false
	
	var g0: String = ast_part[0].to_lower()
	
	if has_alias(g0):
		submit(__aliases[g0], false)
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
		var type_name: String = __TYPE_NAMES[type_value]
		self.log("%s%s%s %s" % [
				__color(COLOR_PRIMARY, g0),
				__color(COLOR_SECONDARY, ":"),
				__color(COLOR_TYPE, type_name),
				__color(COLOR_VALUE, str(result)),
		])
		return false
	
	error("Unrecognized command `%s`." % [" ".join(ast_part)])
	return false


## Appends `msg` to `log_text` and emits `on_log`.
func log(msg: String) -> void:
	__log_text += msg + "\n"
	logged.emit(msg)


## Wraps `msg` with color BBCode and calls `log`.
func info(msg: String) -> void:
	self.log(__color(COLOR_INFO, "[b]info:[/b] %s" % msg))


## Wraps `msg` with color BBCode and calls `log`.
func debug(msg: String) -> void:
	self.log(__color(COLOR_DEBUG, "[b]dbg:[/b] %s" % msg))


## Wraps `msg` with color BBCode and calls `log`.
func warn(msg: String) -> void:
	self.log(__color(COLOR_WARN, "[b]warn:[/b] %s" % msg))


## Wraps `msg` with color BBCode and calls `log`.
func error(msg: String) -> void:
	self.log(__color(COLOR_ERROR, "[b]err:[/b] %s" % msg))


## Calls the enqueued by "wait" commands.
## By default it is called automatically every frame.
## Only required to call manually if `tick_mode` is manual.
## There is no harm calling it manually either way.
func tick() -> void:
	if !__next.size():
		return
	
	var _prev = __next
	__next = []
	
	for ast: Array[PackedStringArray] in _prev:
		__submit_ast(ast)


func _process(_delta: float) -> void:
	if tick_mode == TickMode.TICK_MODE_AUTO:
		tick()


# "wait" and "alias" are non-commands, handled separately in `submit`
func __handle_builtins(cmd_name: String, args: PackedStringArray) -> void:
	if cmd_name == "echo":
		__cmd_echo(args)
	if cmd_name == "exec":
		__cmd_exec(args)
	if cmd_name == "help":
		__cmd_help(args)
	elif cmd_name == "quit":
		get_tree().quit()
	elif cmd_name == "map":
		__cmd_map(args)
	elif cmd_name == "mainscene":
		__cmd_map([ProjectSettings.get_setting("application/run/main_scene")])


func __color(color: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


func __adjust_type(old_value: Variant, new_value: String) -> Variant:
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


func __get_help_color() -> String:
	var color: String = COLORS_HELP[__help_color_idx % COLORS_HELP.size()]
	__help_color_idx = __help_color_idx + 1
	return color


func __cmd_map(args: PackedStringArray) -> void:
	if !args.size():
		self.log(
			"The current scene is '[b]%s[/b]'." % [
				__color(COLOR_VALUE, get_tree().current_scene.scene_file_path),
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
				__color(COLOR_VALUE, args[0]),
			]
		)
		return
	
	self.log(
		"Changing scene to '[b]%s[/b]'..." % [
			__color(COLOR_VALUE, map_name),
		]
	)
	
	get_tree().change_scene_to_file(map_name)
	GsomConsole.hide()


func __cmd_echo(args: PackedStringArray) -> void:
	if !args.size():
		return
	self.log(" ".join(args))


func __cmd_exec(args: PackedStringArray) -> void:
	if !args.size():
		self.log(
			"Syntax: 'exec [b]%s[/b]'." % [
				__color(COLOR_VALUE, "file[%s]" % EXEC_EXT),
			]
		)
		var result: PackedStringArray = []
		__append_exec_path_list(result)
		self.log("".join(result)) # using `self` to avoid name collision
		return
	
	var exec_name: String = args[0]
	__search_and_exec(exec_name)


## Function receives a console script name - with or without extension (`EXEC_EXT`).
## Tries to locate the file in `exec_paths`.
## Each directory is tried first without the file extension, then with extension.
## As soon as the first file match found, the file is read and executed, the search stops.
## The file execution is performed by splitting it line-by line.
## Then non-empty (and non-whitespace) lines are fed to the `submit(text)` method.
func __search_and_exec(exec_name: String) -> void:
	var file: FileAccess = null
	
	for dir_path in exec_paths:
		file = FileAccess.open(dir_path + exec_name, FileAccess.READ)
		if file:
			break
		file = FileAccess.open(dir_path + exec_name + EXEC_EXT, FileAccess.READ)
		if file:
			break
	
	if !file:
		error("Script '[b]%s[/b]' doesn't exist." % [__color(COLOR_VALUE, exec_name)])
		return

	self.log("Executing script '[b]%s[/b]'..." % [__color(COLOR_VALUE, exec_name)])
	while !file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if !line.is_empty():
			submit(line, false)
	file.close()


func __cmd_help(args: PackedStringArray) -> void:
	var i: int = 0
	var result: PackedStringArray = []
	
	# `help [name1, name2, ...]` syntax
	if args.size():
		for arg: String in args:
			var color: String = __get_help_color()
			if __cmds.has(arg):
				result.append(__color(color, "[b]%s[/b] - %s" % [arg, __cmds[arg].help]))
				result.append("\n")
			elif __cvars.has(arg):
				result.append(__color(color, "[b]%s[/b] - %s" % [arg, __cvars[arg].help]))
				result.append("\n")
			else:
				result.append(__color(COLOR_ERROR, "[b]%s[/b] - No such command/variable." % arg))
				result.append("\n")
		
		self.log("".join(PackedStringArray(result)))
		return
	
	__append_cvar_list(result)
	__append_cmd_list(result)
	__append_alias_list(result)
	
	self.log("".join(result)) # using `self` to avoid name collision


# Mutates `dest` by adding CMDs info
func __append_cvar_list(dest: PackedStringArray) -> void:
	if !__cvars.size():
		dest.append("There are no variables, yet.\n")
		return
	
	dest.append("Available variables:\n")
	
	for key: String in __cvars:
		var color: String = __get_help_color()
		dest.append(__color(color, "[b]%s[/b] - %s" % [key, __cvars[key].help]))
		dest.append("\n")


# Mutates `dest` by adding CMDs info
func __append_cmd_list(dest: PackedStringArray) -> void:
	if !__cmds.size():
		dest.append("There are no commands, yet.\n")
		return
	
	dest.append("Available commands:\n")
	
	for key: String in __cmds:
		var color: String = __get_help_color()
		dest.append(__color(color, "[b]%s[/b] - %s" % [key, __cmds[key].help]))
		dest.append("\n")


# Mutates `dest` by adding ALIASes info
func __append_alias_list(dest: PackedStringArray) -> void:
	if !__aliases.size():
		dest.append("There are no aliases, yet.\n")
		return
	
	dest.append("Available aliases:\n")
	
	for key: String in __aliases:
		var color: String = __get_help_color()
		dest.append(__color(color, "[b]%s[/b] - %s" % [key, __aliases[key]]))
		dest.append("\n")


# Mutates `dest` by adding exec paths info
func __append_exec_path_list(dest: PackedStringArray) -> void:
	if !exec_paths.size():
		dest.append("There are no exec paths, yet.\n")
		return
	
	dest.append("Registered exec paths:\n")
	
	for path: String in exec_paths:
		var color: String = __get_help_color()
		dest.append(__color(color, "\t%s\n" % path))


func __history_push(expression: String) -> void:
	var history_len: int = __history.size()
	if history_len and __history[history_len - 1] == expression:
		return
	
	__history.append(expression)
