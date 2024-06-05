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

const _COLORS_HELP = ["#f6d3ff", "#fff6d3", "#d3f6ff", "#f6ffd3"];


var _log_text: String = ""
## The whole log text content. This may be also used to reset the log.
@export var log_text: String = "":
	get:
		return _log_text
	set(v):
		_log_text = v


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


var _cvars: Dictionary = {}
var _cmds: Dictionary = {}
var _help_color_idx: int = 0


func _ready() -> void:
	register_cmd("help", "Display available commands and variables.")
	register_cmd("quit", "Close the application, exit to desktop.")
	called_cmd.connect(
		func (cmd_name: String, args: PackedStringArray) -> void:
			if cmd_name == "help":
				_help(args)
			elif cmd_name == "quit":
				get_tree().quit()
	)
	
	self.log("Type `[b][color=orange]help[/color][/b]` to view existing commands and variables.")


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
	var hint: String = "[color=gray]:[/color] [color=orange]%s[/color] [color=green]%s[/color]" % [
		type_name, adjusted
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
func submit(expression: String) -> void:
	var trimmed: String = expression.strip_edges(true, true)
	
	var r := RegEx.new()
	r.compile("\\S+") # negated whitespace character class
	var groups: Array[RegExMatch] = r.search_all(trimmed)
	
	if groups.size() < 1:
		return
	
	var g0: String = groups[0].get_string()
	
	if has_cmd(g0):
		var args: PackedStringArray = []
		for group in groups.slice(1):
			@warning_ignore("unsafe_method_access")
			args.push_back(group.get_string())
		call_cmd(g0, args)
		_history_push(expression)
		return
	
	if (groups.size() == 1 or groups.size() == 2) and has_cvar(g0):
		if groups.size() == 2:
			var g1: String = groups[1].get_string()
			set_cvar(g0, g1)
		
		var result: Variant = get_cvar(g0)
		var type_value: int = typeof(result)
		var type_name: String = _TYPE_NAMES[type_value]
		self.log("%s%s%s %s" % [
				_color("white", g0),
				_color("gray", ":"),
				_color("orange", type_name),
				_color("green", str(result)),
		])
		_history_push(expression)
		return
	
	error("Unrecognized command `%s`." % [expression])


## Appends `msg` to `log_text` and emits `on_log`.
func log(msg: String) -> void:
	_log_text += msg + "\n"
	logged.emit(msg)


## Wraps `msg` with color BBCode and calls `log`.
func info(msg: String) -> void:
	self.log(_color("#F89D2C", "[b]info:[/b] %s" % msg))


## Wraps `msg` with color BBCode and calls `log`.
func debug(msg: String) -> void:
	self.log(_color("#F89D2C", "[b]dbg:[/b] %s" % msg))


## Wraps `msg` with color BBCode and calls `log`.
func warn(msg: String) -> void:
	self.log(_color("#F89D2C", "[b]warn:[/b] %s" % msg))


## Wraps `msg` with color BBCode and calls `log`.
func error(msg: String) -> void:
	self.log(_color("#E81608", "[b]err:[/b] %s" % msg))


func _color(color: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


func _adjust_type(oldValue: Variant, newValue: String) -> Variant:
	var value_type = typeof(oldValue)
	if value_type == TYPE_BOOL:
		return newValue == "true" or newValue == "1"
	elif value_type == TYPE_INT:
		return int(newValue)
	elif value_type == TYPE_FLOAT:
		return float(newValue)
	elif value_type == TYPE_STRING:
		return newValue
	
	push_warning("GsomConsole.set_cvar: only bool, int, float, string supported.")
	return oldValue


func _get_help_color() -> String:
	var color: String = _COLORS_HELP[_help_color_idx % _COLORS_HELP.size()]
	_help_color_idx = _help_color_idx + 1
	return color;


func _help(args: PackedStringArray) -> void:
	var i: int = 0
	var result: PackedStringArray = []
	
	# `help [name1, name2, ...]` syntax
	if args.size():
		for arg: String in args:
			var color: String = _get_help_color()
			if _cmds.has(arg):
				result.push_back(_color(color, "[b]%s[/b] - %s" % [arg, _cmds[arg].help]))
				result.push_back("\n")
			elif _cvars.has(arg):
				result.push_back(_color(color, "[b]%s[/b] - %s" % [arg, _cvars[arg].help]))
				result.push_back("\n")
			else:
				result.push_back(_color("#E81608", "[b]%s[/b] - No such command/variable." % arg))
				result.push_back("\n")
		
		self.log("".join(PackedStringArray(result)))
		return
	
	result.push_back("Available variables:\n")
	
	for key: String in _cvars:
		var color: String = _get_help_color()
		result.push_back(_color(color, "[b]%s[/b] - %s" % [key, _cvars[key].help]))
		result.push_back("\n")
	
	result.push_back("Available commands:\n")
	
	for key: String in _cmds:
		var color: String = _get_help_color()
		result.push_back(_color(color, "[b]%s[/b] - %s" % [key, _cmds[key].help]))
		result.push_back("\n")
	
	self.log("".join(PackedStringArray(result)))


func _history_push(expression: String) -> void:
	var historyLen: int = _history.size()
	if historyLen and _history[historyLen - 1] == expression:
		return
	
	_history.append(expression)
