extends Control

const __IS_VERBOSE: bool = false

@onready var __label: RichTextLabel = $ScrollContainer/RichTextLabel

func _ready() -> void:
	__test_ast_valid()
	__test_ast_invalid()
	__test_text_matcher()
	__test_console_help()
	__test_console_alias()
	__test_console_echo()
	__test_console_exec()
	__test_console_wait()
	__test_console_greet()
	__test_console_find()
	__test_console_write_cvars()
	__test_console_write_groups()
	__test_console_cvar()
	__test_console_set()
	__test_console_toggle()
	__test_console_ifvi()
	__test_console_ifvv()
	__test_console_inc()
	__test_console_dec()

#region Test Helpers

class Describe:
	var __name: String
	var __has_error: bool
	var __verbose_text: String
	var __label: RichTextLabel
	
	func _init(name: String, label: RichTextLabel) -> void:
		GsomConsole.log_text = ""
		__name = name
		__has_error = false
		__verbose_text = "\n[b]%s[/b]\n\n" % name
		__label = label
	
	func push_error(text: Array[String]) -> void:
		__has_error = true
		__verbose_text += "\t❌ %s\n\n" % "\n\t\t↳ ".join(text)

	func push_ok(text: Array[String]) -> void:
		__verbose_text += "\t✅ %s\n\n" % "\n\t\t↳ ".join(text)

	func flush() -> void:
		if __has_error or __IS_VERBOSE:
			__label.text += __verbose_text
		else:
			__label.text += "\n[b]✅ %s Ok[/b]\n" % __name


func __describe(test_name: String) -> Describe:
	return Describe.new(test_name, __label)

#endregion

#region AST Parser

var __valid_ast_inputs: Dictionary[String, Array] = {
	# Simple 3-token command
	"say hello world": [["say", "hello", "world"]],
	# Quoted argument with space
	"say \"hello world\"": [["say", "hello world"]],
	# Two separate commands
	"ping; pong": [["ping"], ["pong"]],
	# Quoted argument contains semicolon
	"load \"file;name.txt\"": [["load", "file;name.txt"]],
	# Multiple arguments
	"move x y z": [["move", "x", "y", "z"]],
	# Identifier with underscore and number
	"spawn enemy_01 3": [["spawn", "enemy_01", "3"]],
	# Command starts with underscore
	"_init something": [["_init", "something"]],
	# Mixed quoted and plain args across 2 commands
	"alpha \"one two\"; beta three": [["alpha", "one two"], ["beta", "three"]],
	# Quoted semicolons, plus extra param
	"cmd \"quoted;with;semis\" next": [["cmd", "quoted;with;semis", "next"]],
	# Quoted + numeric arg
	"test \"line with spaces\";call 123": [["test", "line with spaces"], ["call", "123"]],
	# Whitespace before semicolon
	"run \"hello world\" ; restart": [["run", "hello world"], ["restart"]],
	# Underscore-heavy command
	"__debug__ \"true\"": [["__debug__", "true"]],
	# Multiple quoted semis
	"echo \"a;b;c\" ; echo2 \"d e f\"": [["echo", "a;b;c"], ["echo2", "d e f"]],
	# Extra spaces (should be ignored)
	"reset   now   please": [["reset", "now", "please"]],
	# Many simple commands
	"one;two;three;four": [["one"], ["two"], ["three"], ["four"]],
	# Starts with space and invalid token
	"  test leading_space": [["test", "leading_space"]],
}

var __invalid_ast_inputs: Dictionary[String, String] = {
	# Line starts with quote, not command name
	"\"unquoted start": "Command must start with a letter or underscore.",
	# Starts with semicolon, no command
	"; lonely semi": "Command must start with a letter or underscore.",
	# Starts with a digit
	"123start param": "Command must start with a letter or underscore.",
	# Invalid command name start (symbol)
	"!cmd param": "Command must start with a letter or underscore.",
	# Unterminated quote
	"say \"unterminated": "Unterminated quoted string.",
	# Unterminated quote with semi
	"say \"bad quote; test": "Unterminated quoted string.",
	# Just empty string, no command
	"\"\"": "Command must start with a letter or underscore.",
	# Command name enclosed in quotes
	"\"cmd\" param": "Command must start with a letter or underscore.",
	# Single quotes are not supported
	"'single quotes'": "Command must start with a letter or underscore.",
	# Starts with @
	"@inject evil": "Command must start with a letter or underscore.",
	# Proper command with unterminated quote
	"say hello \"unfinished": "Unterminated quoted string.",
	# Command name starts with number
	"42 is_the_answer": "Command must start with a letter or underscore.",
}

func __test_ast_valid() -> void:
	var desc := Describe.new("AstParser Valid Input", __label)
	
	for input in __valid_ast_inputs:
		var parser := GsomConsole.AstParser.new(input)
		if parser.error:
			desc.push_error([
				"AstParser Valid Syntax: `%s`" % input,
				"%s" % parser.error,
			])
		elif str(parser.ast) != str(__valid_ast_inputs[input]):
			desc.push_error([
				"AstParser Mismatch AST: `%s`" % input,
				"%s (actual)" % str(parser.ast),
				"%s (expected)" % __valid_ast_inputs[input],
			])
		else:
			desc.push_ok([
				"AstParser Ok `%s`" % input,
				"AST: %s" % str(parser.ast),
			])
	
	desc.flush()


func __test_ast_invalid() -> void:
	var desc := Describe.new("AstParser Invalid Input", __label)
	
	for input in __invalid_ast_inputs:
		var parser := GsomConsole.AstParser.new(input)
		if parser.error == "":
			desc.push_error([
				"AstParser Invalid Syntax: `%s`" % input,
				"Shouldn't be parsed, but it is: %s" % str(parser.ast),
			])
		elif parser.error != __invalid_ast_inputs[input]:
			desc.push_error([
				"AstParser Mismatch Error: `%s`" % input,
				"%s (actual)" % parser.error,
				"%s (expected)" % __invalid_ast_inputs[input],
			])
		else:
			desc.push_ok([
				"`%s`" % input,
				"Correct Error: %s" % parser.error,
			])
	
	desc.flush()

#endregion

#region Console

func __test_console_cvar() -> void:
	var desc := Describe.new("Console CVAR", __label)
	
	GsomConsole.register_cvar("test_console_cvar_bool", false)
	
	if GsomConsole.get_cvar("test_console_cvar_bool") == false:
		desc.push_ok(["bool variable was registered"])
	else:
		desc.push_error(["bool variable not registered"])
	
	GsomConsole.submit("test_console_cvar_bool true")
	if GsomConsole.get_cvar("test_console_cvar_bool") == true:
		desc.push_ok(["bool variable has been set"])
	else:
		desc.push_error(["bool variable not set"])
	
	GsomConsole.register_cvar("test_console_cvar_int", 3)
	
	if GsomConsole.get_cvar("test_console_cvar_int") == 3:
		desc.push_ok(["int variable was registered"])
	else:
		desc.push_error(["int variable not registered"])
	
	GsomConsole.submit("test_console_cvar_int 42")
	if GsomConsole.get_cvar("test_console_cvar_int") == 42:
		desc.push_ok(["int variable has been set"])
	else:
		desc.push_error(["int variable not set"])
	
	GsomConsole.register_cvar("test_console_cvar_float", -8.3)
	
	if GsomConsole.get_cvar("test_console_cvar_float") == -8.3:
		desc.push_ok(["float variable was registered"])
	else:
		desc.push_error(["float variable not registered"])
	
	GsomConsole.submit("test_console_cvar_float -33.2")
	if GsomConsole.get_cvar("test_console_cvar_float") == -33.2:
		desc.push_ok(["float variable has been set"])
	else:
		desc.push_error(["float variable not set"])
	
	GsomConsole.register_cvar("test_console_cvar_str", "before")
	
	if GsomConsole.get_cvar("test_console_cvar_str") == "before":
		desc.push_ok(["str variable was registered"])
	else:
		desc.push_error(["str variable not registered"])
	
	GsomConsole.submit("test_console_cvar_str after")
	if GsomConsole.get_cvar("test_console_cvar_str") == "after":
		desc.push_ok(["str variable has been set"])
	else:
		desc.push_error(["str variable not set"])
	
	desc.flush()


func __test_console_help() -> void:
	var desc := Describe.new("Console Help", __label)
	
	GsomConsole.submit("help")
	if GsomConsole.log_text.contains("There are no variables"):
		desc.push_ok(["`help` variables initially empty"])
	else:
		desc.push_error(["`help` variables should have started empty"])
		
	if GsomConsole.log_text.contains("There are no commands"):
		desc.push_ok(["`help` commands initially empty"])
	else:
		desc.push_error(["`help` commands should have started empty"])
	
	if GsomConsole.log_text.contains("Available built-ins"):
		desc.push_ok(["`help` reports built-ins"])
	else:
		desc.push_error(["`help` missing built-ins"])
		
	GsomConsole.register_cvar("test_cvar", 1, "test variable description text")
	GsomConsole.register_cmd("test_cmd", "test command description text")
	GsomConsole.submit("help")
	if GsomConsole.log_text.contains("test variable description text"):
		desc.push_ok(["`help` reports variables"])
	else:
		desc.push_error(["`help` missing variables"])
	
	if GsomConsole.log_text.contains("Available commands"):
		desc.push_ok(["`help` reports command list"])
	else:
		desc.push_error(["`help` missing command list"])
	
	if GsomConsole.log_text.contains("test command description text"):
		desc.push_ok(["`help` reports commands"])
	else:
		desc.push_error(["`help` missing commands"])
	
	if GsomConsole.log_text.contains("There are no aliases"):
		desc.push_ok(["`help` aliases initially empty"])
	else:
		desc.push_error(["`help` aliases should have started empty"])
	
	GsomConsole.submit("alias test_alias help;help")
	if GsomConsole.log_text.contains("Available aliases"):
		desc.push_ok(["`help` reports aliases"])
	else:
		desc.push_error(["`help` missing aliases"])
	
	desc.flush()


func __test_console_alias() -> void:
	var desc := Describe.new("Console Alias", __label)
	
	GsomConsole.submit("alias say_alias1 say test")
	if GsomConsole.has_key("say_alias1"):
		desc.push_ok(["`say_alias1` registered"])
	else:
		desc.push_error(["`say_alias1` missing"])
	
	GsomConsole.submit("alias help say test")
	if GsomConsole.log_text.contains("Alias name 'help' not available"):
		desc.push_ok(["`help` name already taken"])
	else:
		desc.push_error(["`help` should not have taken a CMD name"])
	
	GsomConsole.register_cvar("test_for_alias", 2, "test")
	GsomConsole.submit("alias test_for_alias say test")
	if GsomConsole.log_text.contains("Alias name 'test_for_alias' not available"):
		desc.push_ok(["`test_for_alias` name already taken"])
	else:
		desc.push_error(["`test_for_alias` should not have taken a CVAR name"])
	
	GsomConsole.submit("alias say_alias1")
	if !GsomConsole.has_key("say_alias1"):
		desc.push_ok(["`say_alias1` erased successfully"])
	else:
		desc.push_error(["`say_alias1` still exists after deletion"])
	
	desc.flush()
	
func __test_console_echo() -> void:
	var desc := Describe.new("Console Echo", __label)
	
	GsomConsole.submit("echo \"echo#1 single string text\"")
	if GsomConsole.log_text.contains("echo#1 single string text"):
		desc.push_ok(["echo#1 correct output"])
	else:
		desc.push_error(["echo#1 incorrect output"])
	
	GsomConsole.submit("echo echo#2 multi arg text")
	if GsomConsole.log_text.contains("echo#2 multi arg text"):
		desc.push_ok(["echo#2 correct output"])
	else:
		desc.push_error(["echo#2 incorrect output"])
	
	GsomConsole.submit("echo echo#3;echo multi;echo command;echo text")
	if GsomConsole.log_text.contains("echo#3\nmulti\ncommand\ntext"):
		desc.push_ok(["echo#3 correct output"])
	else:
		desc.push_error(["echo#3 incorrect output"])
	
	desc.flush()


func __test_console_exec() -> void:
	var desc := Describe.new("Console Exec", __label)
	
	GsomConsole.submit("exec example.cfg")
	if GsomConsole.log_text.contains("registering alias '[b]smile[/b]'"):
		desc.push_ok(["exec with ext worked"])
	else:
		desc.push_error(["exec with ext failed"])
	
	if GsomConsole.log_text.contains("test multi line commands"):
		desc.push_ok(["exec multiline syntax works"])
	else:
		desc.push_error(["exec multiline syntax failed"])
	
	GsomConsole.log_text = ""
	GsomConsole.submit("exec example")
	if GsomConsole.log_text.contains("registering alias '[b]smile[/b]'"):
		desc.push_ok(["exec with ext worked"])
	else:
		desc.push_error(["exec with ext failed"])
	
	desc.flush()


func __test_console_wait() -> void:
	var desc := Describe.new("Console Wait", __label)
	
	GsomConsole.submit("echo test wait 1;wait;echo test wait 2;wait;echo test wait 3", false)
	if GsomConsole.log_text.contains("test wait 1"):
		desc.push_ok(["first part logged"])
	else:
		desc.push_error(["first part not logged"])
	
	if !GsomConsole.log_text.contains("test wait 2"):
		desc.push_ok(["second part is waiting"])
	else:
		desc.push_error(["second part did not wait"])
	
	GsomConsole.tick()
	
	if GsomConsole.log_text.contains("test wait 2"):
		desc.push_ok(["second part logged after wait"])
	else:
		desc.push_error(["second part never logged"])
	
	if !GsomConsole.log_text.contains("test wait 3"):
		desc.push_ok(["third part is waiting"])
	else:
		desc.push_error(["third part did not wait"])
	
	GsomConsole.tick()
	
	if GsomConsole.log_text.contains("test wait 3"):
		desc.push_ok(["third part logged after wait"])
	else:
		desc.push_error(["third part never logged"])
	
	desc.flush()


func __test_console_greet() -> void:
	var desc := Describe.new("Console Greet", __label)
	
	GsomConsole.submit("greet")
	if GsomConsole.log_text.contains("view existing commands and variables"):
		desc.push_ok(["displays greeting message"])
	else:
		desc.push_error(["greeting not displayed"])
	
	desc.flush()


func __test_console_find() -> void:
	var desc := Describe.new("Console Find", __label)
	
	GsomConsole.submit("find ec")
	if (
		GsomConsole.log_text.contains("echo") and
		GsomConsole.log_text.contains("dec") and
		GsomConsole.log_text.contains("exec") and
		GsomConsole.log_text.contains("write_cvars")
	):
		desc.push_ok(["finds the requested commands"])
	else:
		desc.push_error(["did not find 'exec' and ''"])
	
	desc.flush()


func __test_console_write_cvars() -> void:
	var desc := Describe.new("Console Write Cvars", __label)
	
	DirAccess.remove_absolute("user://test_write_cvars.cfg")
	GsomConsole.register_cvar("test_write_cvar", "test-text")
	GsomConsole.submit("write_cvars test_write_cvars.cfg")
	var file: FileAccess = FileAccess.open(
		"user://test_write_cvars.cfg",
		FileAccess.READ,
	)
	
	if file:
		desc.push_ok(["the test file has been written"])
	else:
		desc.push_error(["the test file is missing", OS.get_data_dir()])
		return
	
	var content: String = file.get_as_text(true)
	if content.contains("test_write_cvar test-text"):
		desc.push_ok(["writes cvars to file"])
	else:
		desc.push_error(["cvars not written to file", OS.get_data_dir()])
	
	desc.flush()


func __test_console_write_groups() -> void:
	var desc := Describe.new("Console Write Cvars", __label)
	
	DirAccess.remove_absolute("user://test_write_groups.cfg")
	
	GsomConsole.register_cvar("test_write_groups", "test-text")
	GsomConsole.submit("alias alias_write_groups test_write_groups")
	
	GsomConsole.submit("write_groups test_write_groups.cfg")
	var file: FileAccess = FileAccess.open(
		"user://test_write_groups.cfg",
		FileAccess.READ,
	)
	
	if file:
		desc.push_ok(["the test file has been written"])
	else:
		desc.push_error(["the test file is missing", OS.get_data_dir()])
		return
	
	var content: String = file.get_as_text(true)
	if (
		content.contains("test_write_cvar test-text") and
		content.contains("alias alias_write_groups \"test_write_groups\"")
	):
		desc.push_ok(["writes cvars to file"])
	else:
		desc.push_error(["cvars not written to file", OS.get_data_dir()])
	
	desc.flush()


func __test_console_set() -> void:
	var desc := Describe.new("Console Set", __label)
	
	GsomConsole.register_cvar("test_console_set_bool", false)
	GsomConsole.register_cvar("test_console_set_int", 3)
	GsomConsole.register_cvar("test_console_set_float", -8.3)
	GsomConsole.register_cvar("test_console_set_str", "before")
	
	GsomConsole.submit("set test_console_set_bool true")
	if GsomConsole.get_cvar("test_console_set_bool") == true:
		desc.push_ok(["bool variable has been set"])
	else:
		desc.push_error(["bool variable not set"])
	
	GsomConsole.submit("set test_console_set_int 42")
	if GsomConsole.get_cvar("test_console_set_int") == 42:
		desc.push_ok(["int variable has been set"])
	else:
		desc.push_error(["int variable not set"])
	
	GsomConsole.submit("set test_console_set_float -33.2")
	if GsomConsole.get_cvar("test_console_set_float") == -33.2:
		desc.push_ok(["float variable has been set"])
	else:
		desc.push_error(["float variable not set"])
	
	GsomConsole.submit("set test_console_set_str after")
	if GsomConsole.get_cvar("test_console_set_str") == "after":
		desc.push_ok(["str variable has been set"])
	else:
		desc.push_error(["str variable not set"])
	
	desc.flush()


func __test_console_toggle() -> void:
	var desc := Describe.new("Console Toggle", __label)
	
	GsomConsole.register_cvar("test_console_toggle_bool", false)
	GsomConsole.register_cvar("test_console_toggle_int", 3)
	GsomConsole.register_cvar("test_console_toggle_float", -8.3)
	GsomConsole.register_cvar("test_console_toggle_str", "before")
	
	GsomConsole.submit("toggle test_console_toggle_bool")
	if GsomConsole.get_cvar("test_console_toggle_bool") == true:
		desc.push_ok(["bool variable has been toggled"])
	else:
		desc.push_error(["bool variable not toggled"])
	
	GsomConsole.submit("toggle test_console_toggle_int")
	if GsomConsole.get_cvar("test_console_toggle_int") == 0:
		desc.push_ok(["int variable has been toggled"])
	else:
		desc.push_error(["int variable not toggled"])
	
	GsomConsole.submit("toggle test_console_toggle_float")
	if GsomConsole.get_cvar("test_console_toggle_float") == 8.3:
		desc.push_ok(["float variable has been toggled"])
	else:
		desc.push_error(["float variable not toggled"])
	
	GsomConsole.submit("toggle test_console_toggle_str")
	if GsomConsole.get_cvar("test_console_toggle_str") == "no":
		desc.push_ok(["str variable has been toggled"])
	else:
		desc.push_error(["str variable not toggled"])
	
	desc.flush()


func __test_console_ifvi() -> void:
	var desc := Describe.new("Console Ifvi", __label)
	
	GsomConsole.register_cvar("test_console_ifvi", 3)
	
	GsomConsole.submit("ifvi test_console_ifvi == 3 inc test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 4:
		desc.push_ok(["ifvi equality positive case ok"])
	else:
		desc.push_error(["ifvi equality positive case fail"])
	
	GsomConsole.submit("ifvi test_console_ifvi == 3 inc test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 4:
		desc.push_ok(["ifvi equality negative case ok"])
	else:
		desc.push_error(["ifvi equality negative case fail"])
	
	GsomConsole.submit("ifvi test_console_ifvi > 3 dec test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 3:
		desc.push_ok(["ifvi greater positive case ok"])
	else:
		desc.push_error(["ifvi greater positive case fail"])
	
	GsomConsole.submit("ifvi test_console_ifvi > 3 dec test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 3:
		desc.push_ok(["ifvi greater negative case ok"])
	else:
		desc.push_error(["ifvi greater negative case fail"])
	
	GsomConsole.submit("ifvi test_console_ifvi < 4 inc test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 4:
		desc.push_ok(["ifvi greater positive case ok"])
	else:
		desc.push_error(["ifvi greater positive case fail"])
	
	GsomConsole.submit("ifvi test_console_ifvi < 4 inc test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 4:
		desc.push_ok(["ifvi greater negative case ok"])
	else:
		desc.push_error(["ifvi greater negative case fail"])
	
	desc.flush()

func __test_console_ifvv() -> void:
	var desc := Describe.new("Console Ifvv", __label)
	
	GsomConsole.register_cvar("test_console_ifvv_1", 5.5)
	GsomConsole.register_cvar("test_console_ifvv_2", 5.5)
	
	GsomConsole.submit("ifvv test_console_ifvv_1 == test_console_ifvv_2 inc test_console_ifvv_1")
	if GsomConsole.get_cvar("test_console_ifvv_1") == 6.5:
		desc.push_ok(["ifvv equality positive case ok"])
	else:
		desc.push_error(["ifvv equality positive case fail"])
	
	GsomConsole.submit("ifvv test_console_ifvv_1 == test_console_ifvv_2 inc test_console_ifvv_1")
	if GsomConsole.get_cvar("test_console_ifvv_1") == 6.5:
		desc.push_ok(["ifvv equality negative case ok"])
	else:
		desc.push_error(["ifvv equality negative case fail"])
	
	GsomConsole.submit("ifvv test_console_ifvv_1 > test_console_ifvv_2 dec test_console_ifvv_1")
	if GsomConsole.get_cvar("test_console_ifvv_1") == 5.5:
		desc.push_ok(["ifvv greater positive case ok"])
	else:
		desc.push_error(["ifvv greater positive case fail"])
	
	GsomConsole.submit("ifvv test_console_ifvv_1 > test_console_ifvv_2 dec test_console_ifvv_1")
	if GsomConsole.get_cvar("test_console_ifvv_1") == 5.5:
		desc.push_ok(["ifvv greater negative case ok"])
	else:
		desc.push_error(["ifvv greater negative case fail"])
	
	GsomConsole.set_cvar("test_console_ifvv_2", 6.5)
	GsomConsole.submit("ifvv test_console_ifvv_1 < test_console_ifvv_2 dec test_console_ifvv_2")
	if GsomConsole.get_cvar("test_console_ifvv_2") == 5.5:
		desc.push_ok(["ifvv greater positive case ok"])
	else:
		desc.push_error(["ifvv greater positive case fail"])
	
	GsomConsole.submit("ifvv test_console_ifvv_1 < test_console_ifvv_2 inc test_console_ifvv_1")
	if GsomConsole.get_cvar("test_console_ifvv_1") == 5.5:
		desc.push_ok(["ifvv greater negative case ok"])
	else:
		desc.push_error(["ifvv greater negative case fail"])
	
	desc.flush()

func __test_console_inc() -> void:
	var desc := Describe.new("Console Inc", __label)
	
	GsomConsole.register_cvar("test_console_inc_bool", false)
	GsomConsole.register_cvar("test_console_inc_int", 3)
	GsomConsole.register_cvar("test_console_inc_float", -8.3)
	GsomConsole.register_cvar("test_console_inc_str", "read")
	
	GsomConsole.submit("inc test_console_inc_bool")
	if GsomConsole.get_cvar("test_console_inc_bool") == true:
		desc.push_ok(["bool variable has been incremented"])
	else:
		desc.push_error(["bool variable not incremented"])
	
	GsomConsole.submit("inc test_console_inc_int")
	if GsomConsole.get_cvar("test_console_inc_int") == 4:
		desc.push_ok(["int variable has been incremented"])
	else:
		desc.push_error(["int variable not incremented"])
	
	GsomConsole.submit("inc test_console_inc_float")
	if GsomConsole.get_cvar("test_console_inc_float") == -7.3:
		desc.push_ok(["float variable has been incremented"])
	else:
		desc.push_error([
			"float variable not incremented",
			str(GsomConsole.get_cvar("test_console_inc_float")),
		])
	
	GsomConsole.submit("inc test_console_inc_str y")
	if GsomConsole.get_cvar("test_console_inc_str") == "ready":
		desc.push_ok(["str variable has been incremented"])
	else:
		desc.push_error(["str variable not incremented"])
	
	desc.flush()

func __test_console_dec() -> void:
	var desc := Describe.new("Console Dec", __label)
	
	GsomConsole.register_cvar("test_console_dec_bool", true)
	GsomConsole.register_cvar("test_console_dec_int", 3)
	GsomConsole.register_cvar("test_console_dec_float", -8.3)
	GsomConsole.register_cvar("test_console_dec_str", "read")
	
	GsomConsole.submit("dec test_console_dec_bool")
	if GsomConsole.get_cvar("test_console_dec_bool") == false:
		desc.push_ok(["bool variable has been decremented"])
	else:
		desc.push_error(["bool variable not decremented"])
	
	GsomConsole.submit("dec test_console_dec_int")
	if GsomConsole.get_cvar("test_console_dec_int") == 2:
		desc.push_ok(["int variable has been decremented"])
	else:
		desc.push_error(["int variable not decremented"])
	
	GsomConsole.submit("dec test_console_dec_float")
	if GsomConsole.get_cvar("test_console_dec_float") == -9.3:
		desc.push_ok(["float variable has been decremented"])
	else:
		desc.push_error([
			"float variable not decremented",
			str(GsomConsole.get_cvar("test_console_dec_float")),
		])
	
	GsomConsole.submit("dec test_console_dec_str ad")
	if GsomConsole.get_cvar("test_console_dec_str") == "re":
		desc.push_ok(["str variable has been decremented"])
	else:
		desc.push_error(["str variable not decremented"])
	
	desc.flush()


#endregion

#region Text Matcher

var __matcher_cases: Array[Dictionary] = [
	{
		"text": "test",
		"available": ["contest", "test1", "something"],
		"expected": ["test1", "contest"],
	},
	{
		"text": "mesa",
		"available": ["Mesa", "Message", "Laser", "Admin", "Gordon"],
		"expected": ["Mesa", "Message"],
	},
	{
		"text": "hl",
		"available": ["half", "life", "halflife", "hello"],
		"expected": ["half", "hello", "halflife"],
	},
	{
		"text": "admin",
		"available": ["administrator", "admin1", "domain", "adnin"],
		"expected": ["admin1", "administrator", "adnin"],
	},
	{
		"text": "combine",
		"available": ["Combinator", "combine", "combinee", "combinez", "zombie"],
		"expected": ["combine", "combinee", "combinez"],
	},
	{
		"text": "gordon",
		"available": ["Gordon", "Gordan", "Gord", "Goose"],
		"expected": ["Gordon", "Gordan", "Gord"],
	},
	{
		"text": "xyz",
		"available": ["alpha", "beta", "gamma"],
		"expected": [],
	},
	{
		"text": "sentry",
		"available": ["sentinel", "centry", "sentrybot", "entry"],
		"expected": ["sentrybot"],
	},
	{
		"text": "turret",
		"available": ["turret", "turretgun", "tarret", "truck"],
		"expected": ["turret", "turretgun", "tarret"],
	},
]

func __test_text_matcher() -> void:
	var desc := Describe.new("Text Matcher", __label)
	
	for matcher_case: Dictionary in __matcher_cases:
		var matcher_text: String = matcher_case.text
		var matcher_available: Array = matcher_case.available
		var matched := GsomConsole.TextMatcher.new(matcher_text, matcher_available)
		if str(matched.matched) != str(matcher_case.expected):
			desc.push_error([
				"Text Match: `%s` %s" % [matcher_text, matcher_available],
				"%s (actual)" % str(matched.matched),
				"%s (expected)" % str(matcher_case.expected),
			])
		else:
			desc.push_ok([
				"Text Match: `%s` %s" % [matcher_text, matcher_available],
				"Matched: %s" % str(matched.matched),
			])
	
	desc.flush()

#endregion
