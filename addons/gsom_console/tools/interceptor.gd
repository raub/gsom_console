extends RefCounted

var __help_color_idx: int = 0
var __aliases: Dictionary[String, String] = {}

var __intercepted: Dictionary[String, String] = {
	"greet": "Show introduction/greeting message.",
	"help": "Display available commands and variables.",
	"quit": "Close the application, exit to desktop.",
	"mainscene": "Reload the main scene (as in project settings).",
	"map": "Switch to a scene by path, or show path to the current one.",
	"alias": "Create a named shortcut for any input text.",
	"echo": "Print back any input.",
	"exec": "Parse and execute commands line by line from a file.",
}


func intercept(ast: PackedStringArray) -> bool:
	var cmd_name: String = ast[0].to_lower()
	
	if __try_create_alias(ast):
		return true
	
	var args: PackedStringArray = ast.slice(1)
	
	match cmd_name:
		"greet": __cmd_greet()
		"echo": __cmd_echo(args)
		"exec": __cmd_exec(args)
		"help": __cmd_help(args)
		"quit": GsomConsole.get_tree().quit()
		"map": __cmd_map(args)
		"mainscene": __cmd_map([ProjectSettings.get_setting("application/run/main_scene")])
		_: pass
	
	if __has_alias(cmd_name):
		if args.size() > 1:
			GsomConsole.submit("%s %s" % [__aliases[cmd_name], " ".join(args)], false)
		else:
			GsomConsole.submit(__aliases[cmd_name], false)
		return true
	
	return __intercepted.has(cmd_name)


func get_keys() -> Array[String]:
	var keys = __aliases.keys();
	keys.append_array(__intercepted.keys())
	return keys


func has_key(key:String) -> bool:
	return __intercepted.has(key) or __aliases.has(key)


func __color(color: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]

#region Built-in Commands

func __cmd_greet() -> void:
	GsomConsole.log("Type '[b]%s[/b]' to view existing commands and variables." % [
		__color(GsomConsole.COLOR_VALUE, "help"),
	])


func __cmd_map(args: PackedStringArray) -> void:
	if !args.size():
		GsomConsole.log("The current scene is '[b]%s[/b]'." % [
			__color(GsomConsole.COLOR_VALUE, GsomConsole.get_tree().current_scene.scene_file_path),
		])
		return
	
	# `map [name]` syntax below
	var map_name: String = args[0]
	if !ResourceLoader.exists(map_name):
		map_name += ".tscn"
	if !ResourceLoader.exists(map_name):
		GsomConsole.error("Scene '[b]%s[/b]' doesn't exist." % __color(GsomConsole.COLOR_VALUE, args[0]))
		return
	
	GsomConsole.log("Changing scene to '[b]%s[/b]'..." % __color(GsomConsole.COLOR_VALUE, map_name))
	
	GsomConsole.get_tree().change_scene_to_file(map_name)
	GsomConsole.hide()


func __cmd_echo(args: PackedStringArray) -> void:
	if !args.size():
		return
	GsomConsole.log(" ".join(args))


func __cmd_exec(args: PackedStringArray) -> void:
	if !args.size():
		GsomConsole.log(
			"Syntax: 'exec [b]%s[/b]'." % __color(GsomConsole.COLOR_VALUE, "file[%s]" % GsomConsole.EXEC_EXT),
		)
		var result: PackedStringArray = []
		__append_exec_path_list(result)
		GsomConsole.log("".join(result)) # using `self` to avoid name collision
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
	
	for dir_path in GsomConsole.exec_paths:
		file = FileAccess.open(dir_path + exec_name, FileAccess.READ)
		if file:
			break
		file = FileAccess.open(dir_path + exec_name + GsomConsole.EXEC_EXT, FileAccess.READ)
		if file:
			break
	
	if !file:
		GsomConsole.error("Script '[b]%s[/b]' doesn't exist." % [__color(GsomConsole.COLOR_VALUE, exec_name)])
		return

	GsomConsole.log("Executing script '[b]%s[/b]'..." % [__color(GsomConsole.COLOR_VALUE, exec_name)])
	while !file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if !line.is_empty():
			GsomConsole.submit(line, false)
	file.close()

#endregion

#region Help Command

func __get_help_color() -> String:
	var color: String = GsomConsole.COLORS_HELP[__help_color_idx % GsomConsole.COLORS_HELP.size()]
	__help_color_idx = __help_color_idx + 1
	return color

func __get_builtin_help(name: String) -> String:
	if name == GsomConsole.CMD_WAIT:
		return "A special command to postpone the execution by 1 tick."
	if __intercepted.has(name):
		return __intercepted[name]
	return ""

func __cmd_help(args: PackedStringArray) -> void:
	var i: int = 0
	var result: PackedStringArray = []
	
	# `help [name1, name2, ...]` syntax
	if args.size():
		for arg: String in args:
			var color: String = __get_help_color()
			var builtin_help: String = __get_builtin_help(arg)
			if builtin_help:
				result.append(
					__color(color, "[b]%s[/b] - %s\n" % [arg, builtin_help]),
				)
			if GsomConsole.has_cmd(arg):
				result.append(
					__color(color, "[b]%s[/b] - %s\n" % [arg, GsomConsole.get_cmd_help(arg)]),
				)
			elif GsomConsole.has_cvar(arg):
				result.append(
					__color(color, "[b]%s[/b] - %s\n" % [arg, GsomConsole.get_cvar_help(arg)]),
				)
			elif __has_alias(arg):
				result.append(
					__color(color, "[b]%s[/b] - %s\n" % [arg, __get_alias_help(arg)]),
				)
			else:
				result.append(
					__color(GsomConsole.COLOR_ERROR, "[b]%s[/b] - No such command/variable.\n" % arg)
				)
		
		GsomConsole.log("".join(PackedStringArray(result)))
		return
	
	__append_builtin_list(result)
	__append_cvar_list(result)
	__append_cmd_list(result)
	__append_alias_list(result)
	
	GsomConsole.log("".join(result)) # using `self` to avoid name collision


# Mutates `dest` by adding CMDs info
func __append_builtin_list(dest: PackedStringArray) -> void:
	var keys = __intercepted.keys()
	keys.append(GsomConsole.CMD_WAIT)
	
	dest.append("Available built-ins:\n")
	
	for key: String in keys:
		var color: String = __get_help_color()
		dest.append(__color(color, "\t[b]%s[/b] - %s\n" % [key, __get_builtin_help(key)]))


# Mutates `dest` by adding CMDs info
func __append_cvar_list(dest: PackedStringArray) -> void:
	var keys = GsomConsole.list_cvars()
	if !keys.size():
		dest.append("There are no variables, yet.\n")
		return
	
	dest.append("Available variables:\n")
	
	for key: String in keys:
		var color: String = __get_help_color()
		dest.append(__color(color, "\t[b]%s[/b] - %s\n" % [key, GsomConsole.get_cvar_help(key)]))


# Mutates `dest` by adding CMDs info
func __append_cmd_list(dest: PackedStringArray) -> void:
	var keys = GsomConsole.list_cmds()
	if !keys.size():
		dest.append("There are no commands, yet.\n")
		return
	
	dest.append("Available commands:\n")
	
	for key: String in keys:
		var color: String = __get_help_color()
		dest.append(__color(color, "\t[b]%s[/b] - %s\n" % [key, GsomConsole.get_cmd_help(key)]))


# Mutates `dest` by adding ALIASes info
func __append_alias_list(dest: PackedStringArray) -> void:
	var keys: Array[String] = __list_aliases()
	if !keys.size():
		dest.append("There are no aliases, yet.\n")
		return
	
	dest.append("Available aliases:\n")
	
	for key: String in keys:
		var color: String = __get_help_color()
		dest.append(__color(color, "\t[b]%s[/b] - %s\n" % [key, __get_alias_help(key)]))


# Mutates `dest` by adding exec paths info
func __append_exec_path_list(dest: PackedStringArray) -> void:
	if !GsomConsole.exec_paths.size():
		dest.append("There are no exec paths, yet.\n")
		return
	
	dest.append("Registered exec paths:\n")
	
	for path: String in GsomConsole.exec_paths:
		var color: String = __get_help_color()
		dest.append(__color(color, "\t%s\n" % path))

#endregion

#region Aliases

## Add or remove an alias.
## CVARs and CMDs take precedence - can't override with alias.
## Empty `alias_text` will remove the existing alias.
func alias(alias_name: String, alias_text: String = "") -> void:
	alias_name = alias_name.strip_edges().to_lower()
	
	if GsomConsole.has_cvar(alias_name) or GsomConsole.has_cmd(alias_name):
		GsomConsole.warn("Alias name '%s' not available." % alias_name)
		return
	
	if alias_text:
		__aliases[alias_name] = alias_text
	else:
		__aliases.erase(alias_name)


## Fetch ALIAS help text.
func __get_alias_help(alias_name: String) -> String:
	if !__aliases.has(alias_name):
		GsomConsole.warn("Alias '%s' not found." % alias_name)
		return ""
	
	return __aliases[alias_name]


## List all ALIAS names.
func __list_aliases() -> Array[String]:
	return __aliases.keys()


## Check if there is an ALIAS with given name
func __has_alias(alias_name: String) -> bool:
	return __aliases.has(alias_name)


func __try_create_alias(ast: PackedStringArray) -> bool:
	if ast[0] != "alias":
		return false
	
	if ast.size() == 1:
		var result: PackedStringArray = []
		__append_alias_list(result)
		GsomConsole.log("".join(result)) # using `self` to avoid name collision
		return true
	
	if ast.size() == 2:
		alias(ast[1])
		return true
	
	alias(ast[1], " ".join(ast.slice(2)))
	return true

#endregion
