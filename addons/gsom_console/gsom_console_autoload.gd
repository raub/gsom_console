extends Node

## This is an autoload singleton, that becomes globally available when you enable the plugin.
## It holds all the common console logic and is not tied to any specific UI.


## A CVAR has been changed. You may fetch its updated value
## with `get_cvar(cvar_name)` and react to the change.
signal changed_cvar(cvar_name: String)

## A CMD was called. All listeners will receive the command name and list of args.
signal called_cmd(cmd_name: String, args: PackedStringArray)

## Console visibility toggled.
##
## This is for UI that wants to use the default visibility logic.
## E.g. the UI that is available by default with this addon.
signal toggled(is_visible: bool)

## A log string was added.
##
## Only the latest addition is passed to the signal.
## The whole log text is available as `log_text` prop.
## The argument contains the added text as-is, including the newline.
signal logged(rich_text: String)

## Cleared the console output by a call to `clear()`.
##
## This is to be handled separately (by UIs) because the change is not incremental.
signal cleared()

## Incapsulates common UI logic - you can use it for custom console windows.
const CommonUi := preload('./tools/common_ui.gd')
## Validates (the syntax of) console commands and parses them into AST.
const AstParser := preload('./tools/ast_parser.gd')
## Finds "similar" commands (for hints or built-in "find x")
const TextMatcher := preload('./tools/text_matcher.gd')
## Handles the built-in commands
const Interceptor := preload('./tools/interceptor.gd')
## Half-Life like input handler to support "bind" and other input features.
const IoManager := preload('./tools/io_manager.gd')

const __TYPE_NAMES: Dictionary[int, String] = {
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "String",
}

## Type declaration for CVAR data entry
class CvarDesc:
	var value: Variant
	var help: String
	var hint: String
	var is_frozen: bool
	
	func _init(v: Variant, h: String) -> void:
		value = v
		help = h if !h.is_empty() else "[No description]."
		hint = ""
		is_frozen = false

## Type declaration for CMD data entry
class CmdDesc:
	var help: String
	
	func _init(h: String) -> void:
		help = h if !h.is_empty() else "[No description]."

## For all list outputs these colors can be conveniently cycled through
var COLORS_HELP: Array[String] = ["#d4fdeb", "#d4e6fd", "#fdd4e6", "#fdebd4"]
## Main output color (not default though, default is none)
var COLOR_PRIMARY: String = "#ecf4fe"
## Auxilary output color
var COLOR_SECONDARY: String = "#a3b0c7"
## Extra color for type names
var COLOR_TYPE: String = "#95c1fb"
## Auxilary color for values
var COLOR_VALUE: String = "#f6d386"
## Color for the "info" level logs
var COLOR_INFO: String = "#a29cf5"
## Color for the "debug" level logs
var COLOR_DEBUG: String = "#c3e2e5"
## Color for the "warn" level logs
var COLOR_WARN: String = "#f89d2c"
## Color for the "error" level logs
var COLOR_ERROR: String = "#ff3c2c"

## The special character to seperate commands within a single line.
var CMD_SEPARATOR: String = ";"
## The special command to postpone the execution by 1 tick.
var CMD_WAIT: String = "wait"
## Default file extension for config scripts.
var EXEC_EXT: String = ".cfg"

## An instance of Interceptor that handles built-in command.
var interceptor: Interceptor = Interceptor.new()
## An instance of input manager that handles binds and other input logic.
var io_manager: IoManager = IoManager.new()

var __log_text: String = ""
## The whole log text content. This may be also used to reset the log.
@export var log_text: String = "":
	get:
		return __log_text
	set(v):
		__log_text = v

## Determines how the postponed commands are handled.
enum TickMode {
	## GsomConsole will automatically call `tick()` every frame.
	TICK_MODE_AUTO,
	## You ar to call `tick()` as necessary, no automatic calls.
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
		if v:
			self.show()
		else:
			self.hide()


var __history: PackedStringArray = []
## History of inserted commands. Latest command is last. Duplicate commands not stored.
@export var history: PackedStringArray = []:
	get:
		return __history


var __cvars: Dictionary[String, CvarDesc] = {}
var __cmds: Dictionary[String, CmdDesc] = {}
var __next: Array[Array] = []

#region Input

## Passes input events into the input manager instance.
func handle_input(event: InputEvent) -> void:
	io_manager.handle_input(event)

## Registers a new action name for your game.
func register_action(action_name: String) -> void:
	io_manager.register_action(action_name)

## Removes a previously registered game action by name.
func erase_action(action_name: String) -> void:
	io_manager.erase_action(action_name)

## Fetch the action status by name - pressed or not.
func read_action(action_name: String) -> bool:
	return io_manager.read_action(action_name)

## Binds any console command to the given input name.
##
## An input name is always bound to only 1 command.
## If you need multiple things per input - use ";" or "alias".
## With ";" - `bind x "+jump; say hello; say there"`.
## With "alias" - `alias +greet "+jump; say hello; say there"; bind x +greet`.
func bind_input(input_name: String, command: String) -> void:
	io_manager.bind_input(input_name, command)

## Clears the bound command for the given input name.
func unbind_input(input_name: String) -> void:
	io_manager.unbind_input(input_name)

## Clears all bound commands.
func unbind_all_inputs() -> void:
	io_manager.unbind_all_inputs()

#endregion

#region CVARs

## Makes a new CVAR available with default value and optional help note.
func register_cvar(cvar_name: String, value: Variant, help_text: String = "") -> void:
	if has_key(cvar_name):
		self.warn("CVAR name '%s' not available." % cvar_name)
		return
	
	var value_type: int = typeof(value)
	if (
			value_type != TYPE_BOOL and value_type != TYPE_INT
			and value_type != TYPE_FLOAT and value_type != TYPE_STRING
	):
		self.warn("CVAR: only bool, int, float, string supported.")
		return
	
	__cvars[cvar_name] = CvarDesc.new(value, help_text)
	
	set_cvar(cvar_name, value)

## Converts strings to other supported console types
func convert_value(value_type: int, new_value: String) -> Variant:
	match value_type:
		TYPE_BOOL: return new_value == "true" or new_value == "1"
		TYPE_INT: return int(new_value)
		TYPE_FLOAT: return float(new_value)
		# String and all else
		_: return str(new_value)

func __adjust_type(old_value: Variant, new_value: String) -> Variant:
	var value_type: int = typeof(old_value)
	return convert_value(value_type, new_value)

## Displays a CVAR (type and value) through console log.
func show_cvar(cvar_name: String) -> void:
	if !__cvars.has(cvar_name):
		self.warn("CVAR '%s' not found." % cvar_name)
		return
	var hint: String = __cvars[cvar_name].hint
	self.log(hint)

## Assigns new value to the CVAR.
func set_cvar(cvar_name: String, value: Variant) -> void:
	if !__cvars.has(cvar_name):
		self.warn("CVAR '%s' not found." % cvar_name)
		return
	if __cvars[cvar_name].is_frozen:
		self.warn("CVAR '%s' is read-only." % cvar_name)
		return
	
	var adjusted: Variant = __adjust_type(__cvars[cvar_name].value, str(value))
	
	__cvars[cvar_name].value = adjusted
	var type_value: int = typeof(adjusted)
	var type_name: String = __TYPE_NAMES[type_value]
	var hint: String = "%s%s%s %s" % [
		__color(COLOR_PRIMARY, cvar_name),
		__color(COLOR_SECONDARY, ":"),
		__color(COLOR_TYPE, type_name),
		__color(COLOR_VALUE, str(adjusted)),
	]
	__cvars[cvar_name].hint = hint
	
	changed_cvar.emit(cvar_name)

## Sets CVAR to read-only state.
func freeze_cvar(cvar_name: String, is_frozen: bool = true) -> void:
	if !__cvars.has(cvar_name):
		self.warn("CVAR '%s' not found." % cvar_name)
		return
	
	__cvars[cvar_name].is_frozen = is_frozen
	
	changed_cvar.emit(cvar_name)


## Inspect the current CVAR value.
func get_cvar(cvar_name: String) -> Variant:
	if !__cvars.has(cvar_name):
		self.warn("CVAR '%s' not found." % cvar_name)
		return 0
	
	return __cvars[cvar_name].value


## Fetch CVAR help text.
func get_cvar_help(cvar_name: String) -> String:
	if !__cvars.has(cvar_name):
		self.warn("CVAR '%s' not found." % cvar_name)
		return ""
	
	return __cvars[cvar_name].help


## List all CVAR names.
func list_cvars() -> Array[String]:
	return __cvars.keys()


## Check if there is a CVAR with given name.
func has_cvar(cvar_name: String) -> bool:
	return __cvars.has(cvar_name)

#endregion

#region CMDs

## Makes a new CMD available with an optional help note.
func register_cmd(cmd_name: String, help_text: String = "") -> void:
	if has_key(cmd_name):
		self.warn("CMD name '%s' not available." % cmd_name)
		return
	
	__cmds[cmd_name] = CmdDesc.new(help_text)


## Manually call a command, as if the call was parsed from user input.
func call_cmd(cmd_name: String, args: PackedStringArray) -> void:
	if !__cmds.has(cmd_name):
		self.warn("CMD '%s' not found." % cmd_name)
		return
	
	called_cmd.emit(cmd_name, args)


## Fetch CMD help text.
func get_cmd_help(cmd_name: String) -> String:
	if !__cmds.has(cmd_name):
		self.warn("CMD '%s' not found." % cmd_name)
		return ""
	
	return __cmds[cmd_name].help


## List all CMD names.
func list_cmds() -> Array[String]:
	return __cmds.keys()


## Check if there is a CMD with given name.
func has_cmd(cmd_name: String) -> bool:
	return __cmds.has(cmd_name)

#endregion


## Check if a CMD/CVAR name is already taken.
func has_key(key: String) -> bool:
	return __cvars.has(key) or __cmds.has(key) or interceptor.has_key(key)


## Get a list of Alias, CVAR, and CMD names that start with the given `text`.
func get_matches(text: String) -> PackedStringArray:
	var matches: PackedStringArray = []
	if !text:
		return matches
	
	var common_list: Array[String] = interceptor.get_keys()
	common_list.append_array(__cvars.keys())
	common_list.append_array(__cmds.keys())
	
	var matcher := TextMatcher.new(text, common_list)
	
	return matcher.matched


## Set `is_visible` to `false` if it was `true`. Only emits `toggled` if indeed changed.
func hide() -> void:
	if __is_visible:
		__is_visible = false
		toggled.emit(false)


## Set `is_visible` to `true` if it was `false`. Only emits `toggled` if indeed changed.
func show() -> void:
	if !__is_visible:
		__is_visible = true
		toggled.emit(true)


## Changes the `is_visible` value to the opposite and emits `toggled`.
func toggle() -> void:
	__is_visible = !__is_visible
	toggled.emit(__is_visible)

#region Submit

## Submit user input for parsing.
func submit(expression: String, track_history: bool = false) -> void:
	if track_history:
		self.log("%s %s" % [__color(COLOR_SECONDARY, "\n>"), expression])
	
	var parsed: AstParser = AstParser.new(expression)
	if parsed.error:
		self.error("Syntax error. `%s`" % [parsed.error])
		return
	
	if track_history:
		push_history(expression.strip_edges())
	
	submit_ast(parsed.ast)


## Adds a history item to previously accepted commands.
func push_history(expression: String) -> void:
	var history_len: int = __history.size()
	if history_len and __history[history_len - 1] == expression:
		return
	
	__history.append(expression)


## Same as submit, but takes pre-parsed AST.
func submit_ast(ast: Array[PackedStringArray]) -> void:
	for i: int in ast.size():
		var part: PackedStringArray = ast[i]
		if part[0] == CMD_WAIT:
			__next.append(ast.slice(i + 1))
			break
			
		__submit_part(part)


func __submit_part(ast_part: PackedStringArray) -> void:
	if interceptor.intercept(ast_part):
		return
	
	var g0: String = ast_part[0].to_lower()
	
	if has_cmd(g0):
		call_cmd(g0, ast_part.slice(1))
		return
	
	if (ast_part.size() == 1 or ast_part.size() == 2) and has_cvar(g0):
		if ast_part.size() == 2:
			var g1: String = ast_part[1]
			set_cvar(g0, g1)
		
		show_cvar(g0)
		return
	
	error("Unrecognized command `%s`." % [" ".join(ast_part)])

#endregion

## Crears the output logs and emits `cleared`.
func clear() -> void:
	__log_text = ""
	cleared.emit()

## Appends `msg` to `log_text` and emits `logged`.
func log(msg: String) -> void:
	var with_newline: String = msg + "\n"
	__log_text += with_newline
	logged.emit(with_newline)


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
	
	var _prev: Array[Array] = __next
	__next = []
	
	for ast: Array[PackedStringArray] in _prev:
		submit_ast(ast)


func _process(_delta: float) -> void:
	if tick_mode == TickMode.TICK_MODE_AUTO:
		tick()


func __color(color: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]
