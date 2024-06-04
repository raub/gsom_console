extends Node

signal onChangeCvar(cvar_name: String);
signal onCmd(cmd_name: String, args: Array);
signal onToggle(is_visible: bool);
signal onLog(rich_text: String);

var _is_visible: bool = false;
var _cvars: Dictionary = {};
var _cmds: Dictionary = {};
var _history: PackedStringArray = [];


var _log_text: String = "";
@export var log_text: String = "":
	get:
		return _log_text;
	set(v):
		_log_text = v;

@export var is_visible: bool = false:
	get:
		return _is_visible;
	set(v):
		self['show' if v else 'hide'].call();

@export var history: PackedStringArray = []:
	get:
		return _history;


func _ready() -> void:
	register_cmd("help", "Display available commands and variables.");
	register_cmd("quit", "Close the application, exit to desktop.");
	onCmd.connect(
		func (cmd_name: String, args: Array) -> void:
			if cmd_name == "help":
				_help(args);
			elif cmd_name == "quit":
				get_tree().quit();
	);
	
	self.log("Type `[b][color=orange]help[/color][/b]` to view existing commands and variables.");


const _type_names: Dictionary = {
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "String",
};


func register_cvar(cvar_name: String, value: Variant, help_text: String = "") -> void:
	if _cvars.has(cvar_name) || _cmds.has(cvar_name):
		push_warning("GsomConsole.register_cvar: name '%s' already taken." % cvar_name);
		return;
	
	var value_type: int = typeof(value);
	if value_type != TYPE_BOOL && value_type != TYPE_INT && value_type != TYPE_FLOAT && value_type != TYPE_STRING:
		push_warning("GsomConsole.register_cvar: only bool, int, float, string supported.");
		return;
	
	_cvars[cvar_name] = {
		"value": value,
		"help": help_text if !help_text.is_empty() else "[No description].",
		"hint": "",
	};
	
	set_cvar(cvar_name, value);


func register_cmd(cmd_name: String, help_text: String = "") -> void:
	if _cvars.has(cmd_name) || _cmds.has(cmd_name):
		push_warning("GsomConsole.register_cmd: name '%s' already taken." % cmd_name);
		return;
	
	_cmds[cmd_name] = {
		"help": help_text if !help_text.is_empty() else "[No description].",
	};


func call_cmd(cmd_name: String, args: Array) -> void:
	if !_cmds.has(cmd_name):
		push_warning("GsomConsole.call_cmd: CMD '%s' does not exist." % cmd_name);
		return;
	
	onCmd.emit(cmd_name, args);


func _adjust_type(oldValue: Variant, newValue: String):
	var value_type = typeof(oldValue);
	if value_type == TYPE_BOOL:
		return newValue == "true" || newValue == "1";
	elif value_type == TYPE_INT:
		return int(newValue);
	elif value_type == TYPE_FLOAT:
		return float(newValue);
	elif value_type == TYPE_STRING:
		return newValue;
	
	push_warning("GsomConsole.set_cvar: only bool, int, float, string supported.");
	return oldValue;


func set_cvar(cvar_name: String, value: Variant) -> void:
	if !_cvars.has(cvar_name):
		push_warning("GsomConsole.set_cvar: CVAR %s has not been registered." % cvar_name);
		return;
	
	var adjusted = _adjust_type(_cvars[cvar_name].value, str(value));
	
	_cvars[cvar_name].value = adjusted;
	var type_value: int = typeof(adjusted);
	var type_name: String = _type_names[type_value];
	var hint: String = "[color=gray]:[/color] [color=orange]%s[/color] [color=green]%s[/color]" % [
		type_name, adjusted
	];
	_cvars[cvar_name].hint = hint;
	
	onChangeCvar.emit(cvar_name);


func get_cvar(cvar_name: String) -> Variant:
	if !_cvars.has(cvar_name):
		push_warning("GsomConsole.get_cvar: CVAR %s has not been registered." % cvar_name);
		return 0;
	
	return _cvars[cvar_name].value;


func list_cvars() -> Array:
	return _cvars.keys();


func has_cvar(cvar_name: String) -> bool:
	return _cvars.has(cvar_name);


func has_cmd(cmd_name: String) -> bool:
	return _cmds.has(cmd_name);


func get_matches(text: String) -> Array[String]:
	var matches: Array[String] = [];
	
	if !text:
		return matches;
	
	for k: String in _cvars:
		if k.begins_with(text):
			matches.append(k);
	
	for k: String in _cmds:
		if k.begins_with(text):
			matches.append(k);
	
	return matches;


func _help(args: Array) -> void:
	var colors = ["#f6d3ff", "#fff6d3", "#d3f6ff", "#f6ffd3"];
	var i = 0;
	
	var result: PackedStringArray = [];
	
	if args.size():
		for a in args:
			var c = colors[i % 4];
			i = i + 1;
			if _cmds.has(a):
				result.push_back("[color=%s][b]%s[/b] - %s[/color]\n" % [c, a, _cmds[a].help]);
			elif _cvars.has(a):
				result.push_back("[color=%s][b]%s[/b] - %s[/color]\n" % [c, a, _cvars[a].help]);
			else:
				result.push_back("[color=%s][b][s]%s[/s][/b] - No such command/variable.[/color]\n" % [c, a]);
		
		self.log("".join(PackedStringArray(result)));
		return;
	
	result.push_back("Available variables:\n");
	
	for k in _cvars:
		var c = colors[i % 4];
		i = i + 1;
		result.push_back("[color=%s][b]%s[/b] - %s[/color]\n" % [c, k, _cvars[k].help]);
	
	result.push_back("Available commands:\n");
	
	for k in _cmds:
		var c = colors[i % 4];
		i = i + 1;
		result.push_back("[color=%s][b]%s[/b] - %s[/color]\n" % [c, k, _cmds[k].help]);
	
	self.log("".join(PackedStringArray(result)));


func hide() -> void:
	if !_is_visible:
		return;
	
	_is_visible = false;
	onToggle.emit(false);


func show() -> void:
	if _is_visible:
		return;
	
	_is_visible = true;
	onToggle.emit(true);


func toggle() -> void:
	_is_visible = !_is_visible;
	onToggle.emit(_is_visible);


func _history_push(expression: String) -> void:
	var historyLen: int = _history.size();
	if historyLen && _history[historyLen - 1] == expression:
		return;
	
	_history.append(expression);


func submit(expression: String) -> void:
	var trimmed: String = expression.strip_edges(true, true);
	
	var r = RegEx.new();
	r.compile("\\S+"); # negated whitespace character class
	var groups: Array[RegExMatch] = r.search_all(trimmed);
	
	if groups.size() < 1:
		return;
	
	var g0: String = groups[0].get_string();
	
	if has_cmd(g0):
		var args: Array = [];
		for group in groups.slice(1):
			@warning_ignore("unsafe_method_access")
			args.push_back(group.get_string());
		call_cmd(g0, args);
		_history_push(expression);
		return;
	
	if groups.size() == 1 && has_cvar(g0):
		var result = get_cvar(g0);
		var type_value: int = typeof(result);
		var type_name: String = _type_names[type_value];
		self.log(
			"[color=white]%s[/color][color=gray]:[/color][color=orange]%s[/color] [color=green]%s[/color]" % [g0, type_name, result],
		);
		_history_push(expression);
		return;
	
	if groups.size() == 2 && has_cvar(g0):
		var g1: String = groups[1].get_string();
		set_cvar(g0, g1);
		var result = get_cvar(g0);
		var type_value: int = typeof(result);
		var type_name: String = _type_names[type_value];
		self.log(
			"[color=white]%s[/color][color=gray]:[/color][color=orange]%s[/color] [color=green]%s[/color]" % [g0, type_name, result],
		);
		_history_push(expression);
		return;
	
	error("Unrecognized command `%s`." % [expression]);


func log(msg: String) -> void:
	_log_text += msg + "\n";
	onLog.emit(msg);


func info(msg: String) -> void:
	self.log("[color=#B9B4F8][b]info:[/b] %s[/color]" % msg);


func debug(msg: String) -> void:
	self.log("[color=#9FD1D6][b]dbg:[/b] %s[/color]" % msg);


func warn(msg: String) -> void:
	self.log("[color=#F89D2C][b]warn:[/b] %s[/color]" % msg);


func error(msg: String) -> void:
	self.log("[color=#E81608][b]err:[/b] %s[/color]" % msg);
