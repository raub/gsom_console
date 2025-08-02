extends RefCounted

var __help_color_idx: int = 0
var __aliases: Dictionary[String, String] = {}

var __intercepted: Dictionary[String, String] = {
	"greet": "Show introduction/greeting message. Use `greet \"Your message here\"`.",
	"help": "Display available commands and variables. Use `help name1 name2` or `help`.",
	"quit": "Close the application, exit to desktop.",
	"mainscene": "Reload the main scene (as in project settings).",
	"map": "Switch to a scene by path, or show path to the current one. Use `map test` or `map scenes/test.tscn`.",
	"alias": "Create a named shortcut for any input text. Use `alias say echo` or `alias smile \"echo :)\"`.",
	"echo": "Print back any input. Use `echo text1 2 3` or `echo \"text1 2 3\".`",
	"exec": "Parse and execute commands line by line from a file. Use `exec my_conf` or `exec user.cfg`.",
	"find": "Find matching symbols - similar to how hints work. Use `find ec` or find `it`.",
	"write_cvars": "Save a script file with all or specific CVARs. Use `write_cvars my_conf x y z` or `write_cvars user.cfg`",
	"write_groups": "Save a script file with all or specific groups of symbols - cvar, alias, bind. Use `write_groups my_conf alias bind` or `write_groups user.cfg`",
	"set": "Explicit notation of CVAR assignment. Syntax `set x 1` is equal to `x 1` if `x` is a CVAR. And this will only work on a CVAR.",
	"toggle": "Toggles a CVAR - `toggle x`. Rules are: `true<->false; 1<->0; +f<->-f; ''/'no'<->'yes'/'...'`.",
	"ifvi": "Takes 4+ args: variable, cmp, immediate, ...action. Cmp is one of: ==,!=,>,>=,<,<=. E.g.: `ifvi x == 10 echo x is 10`. True > false, string comparison rules apply too.",
	"ifvv": "Takes 4+ args: variable1, cmp, variable2, ...action. Cmp is one of: ==,!=,>,>=,<,<=. E.g.: `ifvv var1 < var2 \"alias out echo var1\"`.",
	"inc": "Increments CVAR value by 1, 1.0, true, ' ' (depending on type), or your custom values. Use `inc x` or `inc s abcd`.",
	"dec": "Decrements CVAR value by -1, -1.0, false, 1-char (depending on type), or your custom values. Use `dec x` or `dec s xyz`.",
	"condump": "Dumps all the console content into a text file. Takes filename as an optional parameter.",
	"open_user": "Opens the platform-specific location of the `user://` directory. Optionally accepts additional path.",
	"clear": "Clears the console output.",
	"list_bound_commands": "Shows currently bound inputs. Either all, or filtered, if query arguments presend: `list_bound_commands w a s d`.",
	"list_bind_names": "List all available input names, or a filtered subset.",
	"bind": "Assign input name to commands or actions. Pass input name and then a valid console command: `bind w +forward` or `bind x \"say hi;wait;say bye\"`.",
	"unbind": "Erase the bound command text for a given input name: `unbind w` - pressing W does nothing after that.",
	"unbindall": "Erase all the command binds.",
	"toggle_console": "Toggles the console UI on or off (based on built-in state).",
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
		"find": __cmd_find(args)
		"write_cvars": __cmd_write_cvars(args)
		"write_groups": __cmd_write_groups(args)
		"set": __cmd_set(args)
		"toggle": __cmd_toggle(args)
		"ifvi": __cmd_ifvi(args)
		"ifvv": __cmd_ifvv(args)
		"inc": __cmd_inc(args)
		"dec": __cmd_dec(args)
		"condump": __cmd_condump(args)
		"open_user": __cmd_open_user(args)
		"clear": __cmd_clear()
		"list_bound_commands": __cmd_list_bound_commands(args)
		"list_bind_names": __cmd_list_bind_names()
		"bind": __cmd_bind(args)
		"unbind": __cmd_unbind(args)
		"unbindall": __cmd_unbindall()
		"toggle_console": __cmd_toggle_console()
		_: pass
	
	if __has_alias(cmd_name):
		if args.size() > 1:
			GsomConsole.submit("%s %s" % [__aliases[cmd_name], " ".join(args)])
		else:
			GsomConsole.submit(__aliases[cmd_name])
		return true
	
	return __intercepted.has(cmd_name)


func get_keys() -> Array[String]:
	var keys: Array[String] = __aliases.keys();
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

func __cmd_set(args: PackedStringArray) -> void:
	if args.size() < 2:
		GsomConsole.warn("Syntax: 'set name 123'.")
		return
		
	var cvar_name: String = args[0]
	if !GsomConsole.has_cvar(cvar_name):
		GsomConsole.warn("CVAR '%s' not found." % cvar_name)
		return
	
	GsomConsole.set_cvar(cvar_name, args[1])
	GsomConsole.show_cvar(cvar_name)

func __cmd_toggle(args: PackedStringArray) -> void:
	if !args.size():
		GsomConsole.warn("Syntax: 'toggle name'.")
		return
	
	var cvar_name: String = args[0]
	if !GsomConsole.has_cvar(cvar_name):
		GsomConsole.warn("CVAR '%s' not found." % cvar_name)
		return
	
	var value: Variant = GsomConsole.get_cvar(cvar_name)
	var value_type: int = typeof(value)
	match value_type:
		TYPE_BOOL: GsomConsole.set_cvar(cvar_name, !value)
		TYPE_INT: GsomConsole.set_cvar(cvar_name, 0 if value else 1)
		TYPE_FLOAT: GsomConsole.set_cvar(cvar_name, -value)
		# String and all else
		_: GsomConsole.set_cvar(
			cvar_name,
			"yes" if !value or value == "no" else "no",
		)
	GsomConsole.show_cvar(cvar_name)

func __cmd_ifvi(args: PackedStringArray) -> void:
	if args.size() < 4:
		GsomConsole.warn("Syntax requires 4 or more args: 'ifvi var > 1 do_something'.")
		return
	var cvar_name: String = args[0]
	if !GsomConsole.has_cvar(cvar_name):
		GsomConsole.warn("CVAR '%s' not found." % cvar_name)
		return
	
	var value: Variant = GsomConsole.get_cvar(cvar_name)
	var value_type: int = typeof(value)
	
	var immediate: Variant = GsomConsole.convert_value(value_type, args[2])
	
	var cmp_result := false
	match args[1]:
		'==': cmp_result = value == immediate
		'>=': cmp_result = value >= immediate
		'<=': cmp_result = value <= immediate
		'>': cmp_result = value > immediate
		'<': cmp_result = value < immediate
		_: GsomConsole.warn("Unknown comparison operator '%s'." % args[1])
	
	if cmp_result:
		GsomConsole.submit(" ".join(args.slice(3)))

func __cmd_ifvv(args: PackedStringArray) -> void:
	if args.size() < 4:
		GsomConsole.warn("Syntax requires 4 or more args: 'ifvv var1 == var2 do_something'.")
		return
	var cvar_name1: String = args[0]
	if !GsomConsole.has_cvar(cvar_name1):
		GsomConsole.warn("CVAR '%s' not found." % cvar_name1)
		return
	var cvar_name2: String = args[2]
	if !GsomConsole.has_cvar(cvar_name2):
		GsomConsole.warn("CVAR '%s' not found." % cvar_name2)
		return
	
	var value1: Variant = GsomConsole.get_cvar(cvar_name1)
	var value_type: int = typeof(value1)
	
	var value2: Variant = GsomConsole.get_cvar(cvar_name2)
	var converted: Variant = GsomConsole.convert_value(value_type, str(value2))
	
	var cmp_result := false
	match args[1]:
		'==': cmp_result = value1 == converted
		'>=': cmp_result = value1 >= converted
		'<=': cmp_result = value1 <= converted
		'>': cmp_result = value1 > converted
		'<': cmp_result = value1 < converted
		_: GsomConsole.warn("Unknown comparison operator '%s'." % args[1])
	
	if cmp_result:
		GsomConsole.submit(" ".join(args.slice(3)))


func __cmd_inc(args: PackedStringArray) -> void:
	if args.size() < 1:
		GsomConsole.warn("Syntax requires 2 or more args: `inc x` or `inc x 0.132`.")
		return
	var cvar_name: String = args[0]
	if !GsomConsole.has_cvar(cvar_name):
		GsomConsole.warn("CVAR '%s' not found." % cvar_name)
		return
	
	var value: Variant = GsomConsole.get_cvar(cvar_name)
	var value_type: int = typeof(value)
	var immediate: Variant = null
	if args.size() > 1:
		immediate = GsomConsole.convert_value(value_type, args[1])
	
	match value_type:
		TYPE_BOOL:
			GsomConsole.set_cvar(cvar_name, true)
		TYPE_INT:
			var valueInt: int = value
			if immediate == null:
				GsomConsole.set_cvar(cvar_name, valueInt + 1)
			else:
				GsomConsole.set_cvar(cvar_name, valueInt + immediate)
		TYPE_FLOAT:
			var valueFloat: float = value
			if immediate == null:
				GsomConsole.set_cvar(cvar_name, valueFloat + 1.0)
			else:
				GsomConsole.set_cvar(cvar_name, valueFloat + immediate)
		# String and all else
		_:
			var valueStr: String = value
			if immediate == null:
				GsomConsole.set_cvar(cvar_name, valueStr + " ")
			else:
				GsomConsole.set_cvar(cvar_name, valueStr + immediate)
	GsomConsole.show_cvar(cvar_name)


func __cmd_dec(args: PackedStringArray) -> void:
	if args.size() < 1:
		GsomConsole.warn("Syntax requires 2 or more args: `dec x` or `dec x 10`.")
		return
	var cvar_name: String = args[0]
	if !GsomConsole.has_cvar(cvar_name):
		GsomConsole.warn("CVAR '%s' not found." % cvar_name)
		return
	
	var value: Variant = GsomConsole.get_cvar(cvar_name)
	var value_type: int = typeof(value)
	var immediate: Variant = null
	if args.size() > 1:
		immediate = GsomConsole.convert_value(value_type, args[1])
	
	match value_type:
		TYPE_BOOL:
			GsomConsole.set_cvar(cvar_name, false)
		TYPE_INT:
			var valueInt: int = value
			if immediate == null:
				GsomConsole.set_cvar(cvar_name, valueInt - 1)
			else:
				GsomConsole.set_cvar(cvar_name, valueInt - immediate)
		TYPE_FLOAT:
			var valueFloat: float = value
			if immediate == null:
				GsomConsole.set_cvar(cvar_name, valueFloat - 1.0)
			else:
				GsomConsole.set_cvar(cvar_name, valueFloat - immediate)
		# String and all else
		_:
			var valueStr: String = value
			if immediate == null:
				GsomConsole.set_cvar(cvar_name, valueStr.substr(0, valueStr.length() - 1))
			else:
				var imm_string: String = immediate
				GsomConsole.set_cvar(cvar_name, valueStr.rstrip(imm_string))
	GsomConsole.show_cvar(cvar_name)


func __cmd_condump(args: PackedStringArray) -> void:
	var arg_path: String = args[0] if args.size() else "condump.txt"
	var file_path: String = "user://" + arg_path
	
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	
	if !file:
		GsomConsole.warn("File '[b]%s[/b]' can't be written." % file_path)
		return
	
	GsomConsole.log("Dumping the console text to '[b]%s[/b]'." % file_path)
	
	var regex := RegEx.new()
	regex.compile("\\[.+?\\]")
	var clean: String = regex.sub(GsomConsole.log_text, "", true)
	
	file.store_line(clean)

func __cmd_open_user(args: PackedStringArray) -> void:
	var arg_path: String = args[0] if args.size() else ""
	var dir_path: String = "user://" + arg_path
	
	if !DirAccess.dir_exists_absolute(dir_path):
		GsomConsole.warn("Directory '[b]%s[/b]' doesn't exist." % dir_path)
		return
	
	GsomConsole.log("Opening the directory '[b]%s[/b]'." % dir_path)
	
	OS.shell_open(ProjectSettings.globalize_path(dir_path))


func __cmd_clear() -> void:
	GsomConsole.clear()

func __cmd_list_bound_commands(args: PackedStringArray) -> void:
	var result: PackedStringArray = []
	var showUnbound: bool = args.size() > 0
	
	var input_names: Array = (
		Array(args) if args.size() else GsomConsole.io_manager.get_input_names()
	)
	
	for input_name: String in input_names:
		var color: String = __get_help_color()
		var bound: String = GsomConsole.io_manager.get_command_by_name(input_name)
		if bound:
			result.append(__color(color, "[b]%s[/b] - \"%s\"." % [input_name, bound]))
		elif showUnbound:
			result.append(__color(
				GsomConsole.COLOR_SECONDARY,
				"[b]%s[/b] - [lb]Not bound[rb]." % input_name,
			))
	
	if !result.size():
		GsomConsole.log("Currently, no inputs are bound.")
	else:
		GsomConsole.log("\n".join(result))

func __cmd_list_bind_names() -> void:
	var result: PackedStringArray = []
	var input_list: Array[String] = GsomConsole.io_manager.get_input_names()
	
	for input_name: String in input_list:
		var color: String = __get_help_color()
		result.append(__color(color, input_name))
	
	GsomConsole.log(" ".join(result))


func __cmd_bind(args: PackedStringArray) -> void:
	if args.size() < 2:
		GsomConsole.warn("Syntax requires 3 or more args: `bind w +forward` or `bind x say hi`.")
		return
	
	GsomConsole.io_manager.bind_input(args[0], " ".join(args.slice(1)))

func __cmd_unbind(args: PackedStringArray) -> void:
	if args.size() < 1:
		GsomConsole.warn("Syntax requires 2 or more args: `unbind w` or `unbind f1`.")
		return
	GsomConsole.io_manager.unbind_input(args[0])

func __cmd_unbindall() -> void:
	GsomConsole.io_manager.unbind_all_inputs()

func __cmd_toggle_console() -> void:
	GsomConsole.toggle()

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


func __cmd_write_cvars(args: PackedStringArray) -> void:
	if !args.size():
		GsomConsole.warn(
			"Syntax: 'write_cvars [b]%s[/b] [cvar1 cvar2]'." % __color(GsomConsole.COLOR_VALUE, "file[%s]" % GsomConsole.EXEC_EXT),
		)
		return
	
	var file_name: String = "user://" + args[0]
	if !file_name.ends_with(GsomConsole.EXEC_EXT):
		file_name += GsomConsole.EXEC_EXT
	
	var query_keys: PackedStringArray = args.slice(1)
	var available_keys: Array[String] = GsomConsole.list_cvars()
	var cvar_keys: Array[String] = []
	if !query_keys.size():
		cvar_keys = available_keys
	else:
		for key: String in query_keys:
			if available_keys.has(key):
				cvar_keys.append(key)
			else:
				GsomConsole.warn(
					"Requested CVAR '%s' not found." % __color(GsomConsole.COLOR_VALUE, key)
				)
	
	if !cvar_keys.size():
		GsomConsole.warn("No CVARs found to write. The output file will be empty.")
	
	var out_string := ""
	for key: String in cvar_keys:
		out_string += "%s %s\n" % [key, GsomConsole.get_cvar(key)]
	
	var file := FileAccess.open(file_name, FileAccess.WRITE)
	if !file:
		GsomConsole.warn("File '[b]%s[/b]' can't be written." % file_name)
		return
	
	file.store_line(out_string)
	GsomConsole.warn("Written CVARs to file '[b]%s[/b]'.")


func __cmd_write_groups(args: PackedStringArray) -> void:
	if !args.size():
		GsomConsole.warn(
			"Syntax: 'write_groups [b]%s[/b] [cvar alias bind]'." % __color(GsomConsole.COLOR_VALUE, "file[%s]" % GsomConsole.EXEC_EXT),
		)
		return
	
	var file_name: String = "user://" + args[0]
	if !file_name.ends_with(GsomConsole.EXEC_EXT):
		file_name += GsomConsole.EXEC_EXT
	
	var query_groups: PackedStringArray = args.slice(1)
	var out_string := ""
	
	if !query_groups.size() or query_groups.has("cvar"):
		var cvar_batch := ""
		for key: String in GsomConsole.list_cvars():
			cvar_batch += "%s %s\n" % [key, GsomConsole.get_cvar(key)]
		if cvar_batch:
			out_string += "# CVARs\n\n%s" % cvar_batch
	if !query_groups.size() or query_groups.has("alias"):
		var alias_batch := ""
		for key: String in __list_aliases():
			alias_batch += "alias %s \"%s\"\n" % [key, __aliases[key]]
		if alias_batch:
			out_string += "\n\n# Aliases\n\n%s" % alias_batch
	
	if !out_string:
		GsomConsole.warn("No groups found to write. The output file will be empty.")
	
	var file := FileAccess.open(file_name, FileAccess.WRITE)
	if !file:
		GsomConsole.warn("File '[b]%s[/b]' can't be written." % file_name)
		return
	
	file.store_line(out_string)
	GsomConsole.warn("Written file '[b]%s[/b]' with groups: %s." % [
		file_name, ", ".join(query_groups)
	])


# Receives a console script name - with or without extension (`EXEC_EXT`).
# Tries to locate the file in `exec_paths`.
# Each directory is tried first without the file extension, then with extension.
# As soon as the first file match found, the file is read and executed, the search stops.
# The file execution is performed by splitting it line-by line.
# Then non-empty (and non-commented) lines are fed to the `submit(text)` method.
func __search_and_exec(exec_name: String) -> void:
	var file: FileAccess = null
	
	for dir_path: String in GsomConsole.exec_paths:
		file = FileAccess.open(dir_path + exec_name, FileAccess.READ)
		if file:
			break
		file = FileAccess.open(dir_path + exec_name + GsomConsole.EXEC_EXT, FileAccess.READ)
		if file:
			break
	
	if !file:
		GsomConsole.error("Script '[b]%s[/b]' doesn't exist." % __color(GsomConsole.COLOR_VALUE, exec_name))
		return

	GsomConsole.log("Executing script '[b]%s[/b]'..." % __color(GsomConsole.COLOR_VALUE, exec_name))
	
	var line_idx: int = 0;
	var multi_line: String = ""
	
	while !file.eof_reached():
		line_idx += 1
		var new_line: String = file.get_line().strip_edges()
		
		# Skip empty or comment. It also breaks multiline syntax if used.
		if new_line.is_empty() or new_line.begins_with("#") or new_line.begins_with("//"):
			if multi_line.length():
				GsomConsole.warn(
					"Script '[b]%s[/b]' line '[b]%i[/b]': invalid multiline syntax." % [
						__color(GsomConsole.COLOR_VALUE, file.get_path()),
						__color(GsomConsole.COLOR_VALUE, str(line_idx)),
					],
				)
				multi_line = ""
			continue
		
		multi_line = multi_line + new_line
		if multi_line.ends_with("\\"): # merge with next line
			multi_line = multi_line.rstrip("\\")
		else:
			GsomConsole.submit(multi_line)
			multi_line = ""
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

func __cmd_find(args: PackedStringArray) -> void:
	# `find query` - query required
	if !args.size():
		GsomConsole.error(
			"Find requires a query: `find ___` - insert what you wish to find.",
		)
		return
	
	var hint: PackedStringArray = GsomConsole.get_matches(args[0])
	if !hint.size():
		GsomConsole.log(
			"Not found any matching commands for query `%s`." % args[0],
		)
		return
	
	__cmd_help(hint)
	

func __cmd_help(args: PackedStringArray) -> void:
	var result: PackedStringArray = []
	
	# `help [name1 name2 ...]` syntax
	if args.size():
		for arg: String in args:
			var color: String = __get_help_color()
			var builtin_help: String = __get_builtin_help(arg)
			var text := ""
			if builtin_help:
				text = builtin_help
			elif GsomConsole.has_cmd(arg):
				text = GsomConsole.get_cmd_help(arg)
			elif GsomConsole.has_cvar(arg):
				text = GsomConsole.get_cvar_help(arg)
			elif __has_alias(arg):
				text = __get_alias_help(arg)
			
			if text:
				var lines: PackedStringArray = text.split('. ')
				for line_idx: int in range(lines.size()):
					lines[line_idx] = "\t" + lines[line_idx]
				result.append(__color(color, "[b]%s[/b]\n%s\n" % [arg, ".\n".join(lines)]))
			else:
				result.append(
					__color(GsomConsole.COLOR_ERROR, "[b]%s[/b] - No such command/variable.\n" % arg)
				)
		
		GsomConsole.log("".join(result))
		return
	
	__append_builtin_list(result)
	__append_cvar_list(result)
	__append_cmd_list(result)
	__append_alias_list(result)
	
	GsomConsole.log("".join(result)) # using `self` to avoid name collision


# Mutates `dest` by adding CMDs info
func __append_builtin_list(dest: PackedStringArray) -> void:
	var keys: Array[String] = __intercepted.keys()
	keys.append(GsomConsole.CMD_WAIT)
	
	dest.append("Available built-ins:\n")
	
	for key: String in keys:
		var color: String = __get_help_color()
		dest.append(__color(color, "\t[b]%s[/b] - %s\n" % [key, __get_builtin_help(key)]))


# Mutates `dest` by adding CMDs info
func __append_cvar_list(dest: PackedStringArray) -> void:
	var keys: Array[String] = GsomConsole.list_cvars()
	if !keys.size():
		dest.append("There are no variables, yet.\n")
		return
	
	dest.append("Available variables:\n")
	
	for key: String in keys:
		var color: String = __get_help_color()
		dest.append(__color(color, "\t[b]%s[/b] - %s\n" % [key, GsomConsole.get_cvar_help(key)]))


# Mutates `dest` by adding CMDs info
func __append_cmd_list(dest: PackedStringArray) -> void:
	var keys: Array[String] = GsomConsole.list_cmds()
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
	
	if GsomConsole.has_key(alias_name) and !__has_alias(alias_name):
		GsomConsole.warn("Alias name '%s' not available." % alias_name)
		return
	
	if alias_name[0] == "+" or alias_name[0] == "-":
		GsomConsole.io_manager.alias(alias_name, alias_text)
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
