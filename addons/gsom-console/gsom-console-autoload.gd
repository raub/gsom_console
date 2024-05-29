extends Node

signal onChangeCvar(cvarName: String);
signal onCmd(cmdName: String, args: Array);
signal onToggle(isVisible: bool);
signal onLog(richText: String);

var _isVisible: bool = false;
var _cvars: Dictionary = {};
var _cmds: Dictionary = {};
var _log: String = "";
var _history: PackedStringArray = [];


@export var isVisible: bool = false:
	get:
		return _isVisible;
	set(v):
		self['show' if v else 'hide'].call();

@export var history: PackedStringArray = []:
	get:
		return _history;


func _ready() -> void:
	registerCmd("help", "Display available commands and variables.");
	registerCmd("quit", "Close the application, exit to desktop.");
	onCmd.connect(
		func (cmdName: String, args: Array) -> void:
			if cmdName == "help":
				_help(args);
			elif cmdName == "quit":
				_quit(args);
	);
	
	self.log("Type `[b][color=orange]help[/color][/b]` to view existing commands and variables.");


const _typeNames: Dictionary = {
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "String",
};


func registerCvar(cvarName: String, value: Variant, helpText: String = "") -> void:
	if _cvars.has(cvarName) || _cmds.has(cvarName):
		push_warning("Console.registerCvar: name '%s' already taken." % cvarName);
		return;
	
	var valueType = typeof(value);
	if valueType != TYPE_BOOL && valueType != TYPE_INT && valueType != TYPE_FLOAT && valueType != TYPE_STRING:
		push_warning("Console.registerCvar: only bool, int, float, string supported.");
		return;
	
	_cvars[cvarName] = {
		"value": value,
		"help": helpText if !helpText.is_empty() else "[No description].",
		"hint": "",
	};
	
	setCvar(cvarName, value);


func registerCmd(cmdName: String, helpText: String = "") -> void:
	if _cvars.has(cmdName) || _cmds.has(cmdName):
		push_warning("Console.registerCmd: name '%s' already taken." % cmdName);
		return;
	
	_cmds[cmdName] = {
		"help": helpText if !helpText.is_empty() else "[No description].",
	};


func callCmd(cmdName: String, args: Array) -> void:
	if !_cmds.has(cmdName):
		push_warning("Console.callCmd: CMD '%s' does not exist." % cmdName);
		return;
	
	onCmd.emit(cmdName, args);


func _adjustType(oldValue: Variant, newValue: String):
	var valueType = typeof(oldValue);
	if valueType == TYPE_BOOL:
		return newValue == "true" || newValue == "1";
	elif valueType == TYPE_INT:
		return int(newValue);
	elif valueType == TYPE_FLOAT:
		return float(newValue);
	elif valueType == TYPE_STRING:
		return newValue;
	
	push_warning("Console.setCvar: only bool, int, float, string supported.");
	return oldValue;


func setCvar(cvarName: String, value: Variant) -> void:
	if !_cvars.has(cvarName):
		push_warning("Console.setCvar: CVAR %s has not been registered." % cvarName);
		return;
	
	var adjusted = _adjustType(_cvars[cvarName].value, str(value));
	
	_cvars[cvarName].value = adjusted;
	var typeValue: int = typeof(adjusted);
	var typeName: String = _typeNames[typeValue];
	var hint: String = "[color=gray]:[/color] [color=orange]%s[/color] [color=green]%s[/color]" % [
		typeName, adjusted
	];
	_cvars[cvarName].hint = hint;
	
	onChangeCvar.emit(cvarName);


func getCvar(cvarName: String) -> Variant:
	if !_cvars.has(cvarName):
		push_warning("Console.getCvar: CVAR %s has not been registered." % cvarName);
		return 0;
	
	return _cvars[cvarName].value;


func listCvars() -> Array:
	return _cvars.keys();


func hasCvar(cvarName: String) -> bool:
	return _cvars.has(cvarName);


func hasCmd(cmdName: String) -> bool:
	return _cmds.has(cmdName);


func getMatches(text: String) -> Array:
	if !text:
		return [];
	
	var matches = [];
	for k: String in _cvars:
		if k.begins_with(text):
			matches.append(k);
	
	for k: String in _cmds:
		if k.begins_with(text):
			matches.append(k);
	
	return matches;


func _quit(_args: Array) -> void:
	get_tree().quit();


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
	if !_isVisible:
		return;
	
	_isVisible = false;
	onToggle.emit(false);


func show() -> void:
	if _isVisible:
		return;
	
	_isVisible = true;
	onToggle.emit(true);


func toggle() -> void:
	_isVisible = !_isVisible;
	onToggle.emit(_isVisible);


func _historyPush(expression: String) -> void:
	var historyLen: int = _history.size();
	if historyLen && _history[historyLen - 1] == expression:
		return;
	
	_history.append(expression);


func submit(expression: String) -> void:
	var trimmed: String = expression.strip_edges(true, true);
	
	var r = RegEx.new()
	r.compile("\\S+") # negated whitespace character class
	var groups: Array[RegExMatch] = r.search_all(trimmed);
	
	if groups.size() < 1:
		return;
	
	var g0: String = groups[0].get_string();
	
	if self.hasCmd(g0):
		var args: Array = [];
		for group in groups.slice(1):
			@warning_ignore("unsafe_method_access")
			args.push_back(group.get_string());
		self.callCmd(g0, args);
		_historyPush(expression);
		return;
	
	if groups.size() == 1 && self.hasCvar(g0):
		var result = self.getCvar(g0);
		var typeValue: int = typeof(result);
		var typeName: String = _typeNames[typeValue];
		self.log(
			"[color=white]%s[/color][color=gray]:[/color][color=orange]%s[/color] [color=green]%s[/color]" % [g0, typeName, result],
		);
		_historyPush(expression);
		return;
	
	if groups.size() == 2 && self.hasCvar(g0):
		var g1: String = groups[1].get_string();
		self.setCvar(g0, g1);
		var result = self.getCvar(g0);
		var typeValue: int = typeof(result);
		var typeName: String = _typeNames[typeValue];
		self.log(
			"[color=white]%s[/color][color=gray]:[/color][color=orange]%s[/color] [color=green]%s[/color]" % [g0, typeName, result],
		);
		_historyPush(expression);
		return;
	
	self.error("Unrecognized command `%s`." % [expression]);


func log(msg: String) -> void:
	_log += msg + "\n";
	onLog.emit(msg);


func info(msg: String) -> void:
	self.log("[color=#B9B4F8][b]info:[/b] %s[/color]" % msg);


func debug(msg: String) -> void:
	self.log("[color=#9FD1D6][b]dbg:[/b] %s[/color]" % msg);


func warn(msg: String) -> void:
	self.log("[color=#F89D2C][b]warn:[/b] %s[/color]" % msg);


func error(msg: String) -> void:
	self.log("[color=#E81608][b]err:[/b] %s[/color]" % msg);
