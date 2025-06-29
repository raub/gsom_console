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
var COLOR_ERROR: String = "#ff3c2c" # "#e81608"

var CMD_SEPARATOR: String = ";"
var CMD_WAIT: String = "wait"


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

var tick_mode: TickMode = TickMode.TICK_MODE_AUTO

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


var _cvars: Dictionary[String, Dictionary] = {}
var _cmds: Dictionary[String, Dictionary] = {}
var _aliases: Dictionary[String, String] = {}
var _next: PackedStringArray = []
var _help_color_idx: int = 0


func _ready() -> void:
	register_cmd("help", "Display available commands and variables.")
	register_cmd("quit", "Close the application, exit to desktop.")
	register_cmd("mainscene", "Reload the main scene (as in project settings).")
	register_cmd("map", "Switch to a scene by path, or show path to the current one.")
	register_cmd("alias", "Create a named shortcut for any input text.")
	register_cmd("echo", "Print back any input.")
	
	called_cmd.connect(_handle_builtins)
	
	self.log(
		"Type `%s` to view existing commands and variables." % [
			_color(COLOR_VALUE, "[b]help[/b]"),
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
func list_cvars() -> Array:
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
## Automatically separates by `CMD_SEPARATOR`.
## Detects CMD_WAIT and postpones the rest
func submit(expression: String, track_history: bool = true) -> void:
	var trimmed: String = expression.strip_edges(true, true)
	
	if _fetch_alias(trimmed, track_history):
		return
	
	var parts: PackedStringArray = trimmed.split(CMD_SEPARATOR, false)
	
	for idx: int in range(parts.size()):
		var part: String = parts[idx]
		if _submit_part(part, track_history):
			if parts.size() > idx + 1:
				_next.append_array(parts.slice(idx + 1))
			return


func _fetch_alias(trimmed: String, track_history: bool) -> bool:
	var r := RegEx.new()
	r.compile("^alias\\s+")
	var found_alias: RegExMatch = r.search(trimmed)
	if !found_alias:
		return false
	
	var alias_text: String = trimmed.substr(found_alias.get_string().length())
	
	if !alias_text:
		var result: PackedStringArray = []
		_append_alias_list(result)
		self.log("".join(result)) # using `self` to avoid name collision
		return true
	
	var r1 := RegEx.new()
	r1.compile("\\S+") # negated whitespace character class
	var alias_groups: Array[RegExMatch] = r1.search_all(alias_text)
	var alias_name: String = alias_groups[0].get_string()
	
	if alias_groups.size() < 2:
		alias(alias_name)
		return true
	
	var alias_rest: String = alias_text.substr(alias_name.length());
	alias(alias_name, alias_rest.strip_edges(true, true))
	return true
	

func _submit_part(expression: String, track_history: bool) -> bool:
	var trimmed: String = expression.strip_edges(true, true)
	
	var r := RegEx.new()
	r.compile("\\S+") # negated whitespace character class
	var groups: Array[RegExMatch] = r.search_all(trimmed)
	
	if groups.size() < 1:
		return false
	
	var g0: String = groups[0].get_string()
	
	if g0 == CMD_WAIT:
		return true
	
	if has_alias(g0):
		_history_push(expression)
		submit(_aliases[g0], false)
		return false
	
	if has_cmd(g0):
		var args: PackedStringArray = []
		for group: RegExMatch in groups.slice(1):
			args.append(group.get_string())
		call_cmd(g0, args)
		_history_push(expression)
		return false
	
	if (groups.size() == 1 or groups.size() == 2) and has_cvar(g0):
		if groups.size() == 2:
			var g1: String = groups[1].get_string()
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
		_history_push(expression)
		return false
	
	error("Unrecognized command `%s`." % [expression])
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
	if _next.size():
		var prev: String = ";".join(_next)
		_next.clear()
		submit(prev)


func _process(_delta: float) -> void:
	if tick_mode == TickMode.TICK_MODE_AUTO:
		tick()


# "wait" and "alias" are non-commands, handled separately in `submit`
func _handle_builtins(cmd_name: String, args: PackedStringArray) -> void:
	if cmd_name == "echo":
		_cmd_echo(args)
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
		self.log("The current scene is '%s'." % get_tree().current_scene.scene_file_path)
		return
	
	# `map [name]` syntax below
	var map_name: String = args[0]
	if !ResourceLoader.exists(map_name):
		map_name += ".tscn"
	if !ResourceLoader.exists(map_name):
		error("Scene '%s' doesn't exist." % args[0])
		return
	
	info("Changing scene to '%s'..." % args[0])
	get_tree().change_scene_to_file(map_name)
	GsomConsole.hide()


func _cmd_echo(args: PackedStringArray) -> void:
	if !args.size():
		return
	self.log(" ".join(args))


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
		return;
	
	dest.append("Available aliases:\n")
	
	for key: String in _aliases:
		var color: String = _get_help_color()
		dest.append(_color(color, "[b]%s[/b] - %s" % [key, _aliases[key]]))
		dest.append("\n")


func _history_push(expression: String) -> void:
	var history_len: int = _history.size()
	if history_len and _history[history_len - 1] == expression:
		return
	
	_history.append(expression)
