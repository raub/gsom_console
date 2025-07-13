extends Control

const __IS_VERBOSE: bool = false

@onready var __label = $ScrollContainer/RichTextLabel

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

func __describe(test_name: String) -> Dictionary:
	GsomConsole.log_text = ""
	return {
		"name": test_name,
		"has_error": false,
		"verbose_text": "\n[b]%s[/b]\n\n" % test_name,
	}

func __push_error(desc: Dictionary, text: Array[String]) -> void:
	desc.has_error = true
	desc.verbose_text += "\t❌ %s\n\n" % "\n\t\t↳ ".join(text)

func __push_ok(desc: Dictionary, text: Array[String]) -> void:
	desc.verbose_text += "\t✅ %s\n\n" % "\n\t\t↳ ".join(text)

func __flush(desc: Dictionary) -> void:
	if desc.has_error or __IS_VERBOSE:
		__label.text += desc.verbose_text
	else:
		__label.text += "\n[b]✅ %s Ok[/b]\n" % desc.name

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
	var desc: Dictionary = __describe("AstParser Valid Input")
	
	for input in __valid_ast_inputs:
		var parser := GsomConsole.AstParser.new(input)
		if parser.error:
			__push_error(desc, [
				"AstParser Valid Syntax: `%s`" % input,
				"%s" % parser.error,
			])
		elif str(parser.ast) != str(__valid_ast_inputs[input]):
			__push_error(desc, [
				"AstParser Mismatch AST: `%s`" % input,
				"%s (actual)" % str(parser.ast),
				"%s (expected)" % __valid_ast_inputs[input],
			])
		else:
			__push_ok(desc, [
				"AstParser Ok `%s`" % input,
				"AST: %s" % str(parser.ast),
			])
	
	__flush(desc)


func __test_ast_invalid() -> void:
	var desc: Dictionary = __describe("AstParser Invalid Input")
	
	for input in __invalid_ast_inputs:
		var parser := GsomConsole.AstParser.new(input)
		if parser.error == "":
			__push_error(desc, [
				"AstParser Invalid Syntax: `%s`" % input,
				"Shouldn't be parsed, but it is: %s" % str(parser.ast),
			])
		elif parser.error != __invalid_ast_inputs[input]:
			__push_error(desc, [
				"AstParser Mismatch Error: `%s`" % input,
				"%s (actual)" % parser.error,
				"%s (expected)" % __invalid_ast_inputs[input],
			])
		else:
			__push_ok(desc, [
				"`%s`" % input,
				"Correct Error: %s" % parser.error,
			])
	
	__flush(desc)

#endregion

#region Console

func __test_console_cvar() -> void:
	var desc: Dictionary = __describe("Console CVAR")
	
	GsomConsole.register_cvar("test_console_cvar_bool", false)
	
	if GsomConsole.get_cvar("test_console_cvar_bool") == false:
		__push_ok(desc, ["bool variable was registered"])
	else:
		__push_error(desc, ["bool variable not registered"])
	
	GsomConsole.submit("test_console_cvar_bool true")
	if GsomConsole.get_cvar("test_console_cvar_bool") == true:
		__push_ok(desc, ["bool variable has been set"])
	else:
		__push_error(desc, ["bool variable not set"])
	
	GsomConsole.register_cvar("test_console_cvar_int", 3)
	
	if GsomConsole.get_cvar("test_console_cvar_int") == 3:
		__push_ok(desc, ["int variable was registered"])
	else:
		__push_error(desc, ["int variable not registered"])
	
	GsomConsole.submit("test_console_cvar_int 42")
	if GsomConsole.get_cvar("test_console_cvar_int") == 42:
		__push_ok(desc, ["int variable has been set"])
	else:
		__push_error(desc, ["int variable not set"])
	
	GsomConsole.register_cvar("test_console_cvar_float", -8.3)
	
	if GsomConsole.get_cvar("test_console_cvar_float") == -8.3:
		__push_ok(desc, ["float variable was registered"])
	else:
		__push_error(desc, ["float variable not registered"])
	
	GsomConsole.submit("test_console_cvar_float -33.2")
	if GsomConsole.get_cvar("test_console_cvar_float") == -33.2:
		__push_ok(desc, ["float variable has been set"])
	else:
		__push_error(desc, ["float variable not set"])
	
	GsomConsole.register_cvar("test_console_cvar_str", "before")
	
	if GsomConsole.get_cvar("test_console_cvar_str") == "before":
		__push_ok(desc, ["str variable was registered"])
	else:
		__push_error(desc, ["str variable not registered"])
	
	GsomConsole.submit("test_console_cvar_str after")
	if GsomConsole.get_cvar("test_console_cvar_str") == "after":
		__push_ok(desc, ["str variable has been set"])
	else:
		__push_error(desc, ["str variable not set"])
	
	__flush(desc)


func __test_console_help() -> void:
	var desc: Dictionary = __describe("Console Help")
	
	GsomConsole.submit("help")
	if GsomConsole.log_text.contains("There are no variables"):
		__push_ok(desc, ["`help` variables initially empty"])
	else:
		__push_error(desc, ["`help` variables should have started empty"])
		
	if GsomConsole.log_text.contains("There are no commands"):
		__push_ok(desc, ["`help` commands initially empty"])
	else:
		__push_error(desc, ["`help` commands should have started empty"])
	
	if GsomConsole.log_text.contains("Available built-ins"):
		__push_ok(desc, ["`help` reports built-ins"])
	else:
		__push_error(desc, ["`help` missing built-ins"])
		
	GsomConsole.register_cvar("test_cvar", 1, "test variable description text")
	GsomConsole.register_cmd("test_cmd", "test command description text")
	GsomConsole.submit("help")
	if GsomConsole.log_text.contains("test variable description text"):
		__push_ok(desc, ["`help` reports variables"])
	else:
		__push_error(desc, ["`help` missing variables"])
	
	if GsomConsole.log_text.contains("Available commands"):
		__push_ok(desc, ["`help` reports command list"])
	else:
		__push_error(desc, ["`help` missing command list"])
	
	if GsomConsole.log_text.contains("test command description text"):
		__push_ok(desc, ["`help` reports commands"])
	else:
		__push_error(desc, ["`help` missing commands"])
	
	if GsomConsole.log_text.contains("There are no aliases"):
		__push_ok(desc, ["`help` aliases initially empty"])
	else:
		__push_error(desc, ["`help` aliases should have started empty"])
	
	GsomConsole.submit("alias test_alias help;help")
	if GsomConsole.log_text.contains("Available aliases"):
		__push_ok(desc, ["`help` reports aliases"])
	else:
		__push_error(desc, ["`help` missing aliases"])
	
	__flush(desc)


func __test_console_alias() -> void:
	var desc: Dictionary = __describe("Console Alias")
	
	GsomConsole.submit("alias say_alias1 say test")
	if GsomConsole.has_key("say_alias1"):
		__push_ok(desc, ["`say_alias1` registered"])
	else:
		__push_error(desc, ["`say_alias1` missing"])
	
	GsomConsole.submit("alias help say test")
	if GsomConsole.log_text.contains("Alias name 'help' not available"):
		__push_ok(desc, ["`help` name already taken"])
	else:
		__push_error(desc, ["`help` should not have taken a CMD name"])
	
	GsomConsole.register_cvar("test_for_alias", 2, "test")
	GsomConsole.submit("alias test_for_alias say test")
	if GsomConsole.log_text.contains("Alias name 'test_for_alias' not available"):
		__push_ok(desc, ["`test_for_alias` name already taken"])
	else:
		__push_error(desc, ["`test_for_alias` should not have taken a CVAR name"])
	
	GsomConsole.submit("alias say_alias1")
	if !GsomConsole.has_key("say_alias1"):
		__push_ok(desc, ["`say_alias1` erased successfully"])
	else:
		__push_error(desc, ["`say_alias1` still exists after deletion"])
	
	__flush(desc)
	
func __test_console_echo() -> void:
	var desc: Dictionary = __describe("Console Echo")
	
	GsomConsole.submit("echo \"echo#1 single string text\"")
	if GsomConsole.log_text.contains("echo#1 single string text"):
		__push_ok(desc, ["echo#1 correct output"])
	else:
		__push_error(desc, ["echo#1 incorrect output"])
	
	GsomConsole.submit("echo echo#2 multi arg text")
	if GsomConsole.log_text.contains("echo#2 multi arg text"):
		__push_ok(desc, ["echo#2 correct output"])
	else:
		__push_error(desc, ["echo#2 incorrect output"])
	
	GsomConsole.submit("echo echo#3;echo multi;echo command;echo text")
	if GsomConsole.log_text.contains("echo#3\nmulti\ncommand\ntext"):
		__push_ok(desc, ["echo#3 correct output"])
	else:
		__push_error(desc, ["echo#3 incorrect output"])
	
	__flush(desc)


func __test_console_exec() -> void:
	var desc: Dictionary = __describe("Console Exec")
	
	GsomConsole.submit("exec example.cfg")
	if GsomConsole.log_text.contains("registering alias '[b]smile[/b]'"):
		__push_ok(desc, ["exec with ext worked"])
	else:
		__push_error(desc, ["exec with ext failed"])
	
	if GsomConsole.log_text.contains("test multi line commands"):
		__push_ok(desc, ["exec multiline syntax works"])
	else:
		__push_error(desc, ["exec multiline syntax failed"])
	
	GsomConsole.log_text = ""
	GsomConsole.submit("exec example")
	if GsomConsole.log_text.contains("registering alias '[b]smile[/b]'"):
		__push_ok(desc, ["exec with ext worked"])
	else:
		__push_error(desc, ["exec with ext failed"])
	
	__flush(desc)


func __test_console_wait() -> void:
	var desc: Dictionary = __describe("Console Wait")
	
	GsomConsole.submit("echo test wait 1;wait;echo test wait 2;wait;echo test wait 3", false)
	if GsomConsole.log_text.contains("test wait 1"):
		__push_ok(desc, ["first part logged"])
	else:
		__push_error(desc, ["first part not logged"])
	
	if !GsomConsole.log_text.contains("test wait 2"):
		__push_ok(desc, ["second part is waiting"])
	else:
		__push_error(desc, ["second part did not wait"])
	
	GsomConsole.tick()
	
	if GsomConsole.log_text.contains("test wait 2"):
		__push_ok(desc, ["second part logged after wait"])
	else:
		__push_error(desc, ["second part never logged"])
	
	if !GsomConsole.log_text.contains("test wait 3"):
		__push_ok(desc, ["third part is waiting"])
	else:
		__push_error(desc, ["third part did not wait"])
	
	GsomConsole.tick()
	
	if GsomConsole.log_text.contains("test wait 3"):
		__push_ok(desc, ["third part logged after wait"])
	else:
		__push_error(desc, ["third part never logged"])
	
	__flush(desc)


func __test_console_greet() -> void:
	var desc: Dictionary = __describe("Console Greet")
	
	GsomConsole.submit("greet")
	if GsomConsole.log_text.contains("view existing commands and variables"):
		__push_ok(desc, ["displays greeting message"])
	else:
		__push_error(desc, ["greeting not displayed"])
	
	__flush(desc)


func __test_console_find() -> void:
	var desc: Dictionary = __describe("Console Find")
	
	GsomConsole.submit("find ec")
	if (
		GsomConsole.log_text.contains("echo") and
		GsomConsole.log_text.contains("dec") and
		GsomConsole.log_text.contains("exec") and
		GsomConsole.log_text.contains("write_cvars")
	):
		__push_ok(desc, ["finds the requested commands"])
	else:
		__push_error(desc, ["did not find 'exec' and ''"])
	
	__flush(desc)


func __test_console_write_cvars() -> void:
	var desc: Dictionary = __describe("Console Write Cvars")
	
	DirAccess.remove_absolute("user://test_write_cvars.cfg")
	GsomConsole.register_cvar("test_write_cvar", "test-text")
	GsomConsole.submit("write_cvars test_write_cvars.cfg")
	var file: FileAccess = FileAccess.open(
		"user://test_write_cvars.cfg",
		FileAccess.READ,
	)
	
	if file:
		__push_ok(desc, ["the test file has been written"])
	else:
		__push_error(desc, ["the test file is missing", OS.get_data_dir()])
		return
	
	var content = file.get_as_text(true)
	if content.contains("test_write_cvar test-text"):
		__push_ok(desc, ["writes cvars to file"])
	else:
		__push_error(desc, ["cvars not written to file", OS.get_data_dir()])
	
	__flush(desc)


func __test_console_write_groups() -> void:
	var desc: Dictionary = __describe("Console Write Cvars")
	
	DirAccess.remove_absolute("user://test_write_groups.cfg")
	
	GsomConsole.register_cvar("test_write_groups", "test-text")
	GsomConsole.submit("alias alias_write_groups test_write_groups")
	
	GsomConsole.submit("write_groups test_write_groups.cfg")
	var file: FileAccess = FileAccess.open(
		"user://test_write_groups.cfg",
		FileAccess.READ,
	)
	
	if file:
		__push_ok(desc, ["the test file has been written"])
	else:
		__push_error(desc, ["the test file is missing", OS.get_data_dir()])
		return
	
	var content = file.get_as_text(true)
	if (
		content.contains("test_write_cvar test-text") and
		content.contains("alias alias_write_groups \"test_write_groups\"")
	):
		__push_ok(desc, ["writes cvars to file"])
	else:
		__push_error(desc, ["cvars not written to file", OS.get_data_dir()])
	
	__flush(desc)


func __test_console_set() -> void:
	var desc: Dictionary = __describe("Console Set")
	
	GsomConsole.register_cvar("test_console_set_bool", false)
	GsomConsole.register_cvar("test_console_set_int", 3)
	GsomConsole.register_cvar("test_console_set_float", -8.3)
	GsomConsole.register_cvar("test_console_set_str", "before")
	
	GsomConsole.submit("set test_console_set_bool true")
	if GsomConsole.get_cvar("test_console_set_bool") == true:
		__push_ok(desc, ["bool variable has been set"])
	else:
		__push_error(desc, ["bool variable not set"])
	
	GsomConsole.submit("set test_console_set_int 42")
	if GsomConsole.get_cvar("test_console_set_int") == 42:
		__push_ok(desc, ["int variable has been set"])
	else:
		__push_error(desc, ["int variable not set"])
	
	GsomConsole.submit("set test_console_set_float -33.2")
	if GsomConsole.get_cvar("test_console_set_float") == -33.2:
		__push_ok(desc, ["float variable has been set"])
	else:
		__push_error(desc, ["float variable not set"])
	
	GsomConsole.submit("set test_console_set_str after")
	if GsomConsole.get_cvar("test_console_set_str") == "after":
		__push_ok(desc, ["str variable has been set"])
	else:
		__push_error(desc, ["str variable not set"])
	
	__flush(desc)


func __test_console_toggle() -> void:
	var desc: Dictionary = __describe("Console Toggle")
	
	GsomConsole.register_cvar("test_console_toggle_bool", false)
	GsomConsole.register_cvar("test_console_toggle_int", 3)
	GsomConsole.register_cvar("test_console_toggle_float", -8.3)
	GsomConsole.register_cvar("test_console_toggle_str", "before")
	
	GsomConsole.submit("toggle test_console_toggle_bool")
	if GsomConsole.get_cvar("test_console_toggle_bool") == true:
		__push_ok(desc, ["bool variable has been toggled"])
	else:
		__push_error(desc, ["bool variable not toggled"])
	
	GsomConsole.submit("toggle test_console_toggle_int")
	if GsomConsole.get_cvar("test_console_toggle_int") == 0:
		__push_ok(desc, ["int variable has been toggled"])
	else:
		__push_error(desc, ["int variable not toggled"])
	
	GsomConsole.submit("toggle test_console_toggle_float")
	if GsomConsole.get_cvar("test_console_toggle_float") == 8.3:
		__push_ok(desc, ["float variable has been toggled"])
	else:
		__push_error(desc, ["float variable not toggled"])
	
	GsomConsole.submit("toggle test_console_toggle_str")
	if GsomConsole.get_cvar("test_console_toggle_str") == "no":
		__push_ok(desc, ["str variable has been toggled"])
	else:
		__push_error(desc, ["str variable not toggled"])
	
	__flush(desc)


func __test_console_ifvi() -> void:
	var desc: Dictionary = __describe("Console Ifvi")
	
	GsomConsole.register_cvar("test_console_ifvi", 3)
	
	GsomConsole.submit("ifvi test_console_ifvi == 3 inc test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 4:
		__push_ok(desc, ["ifvi equality positive case ok"])
	else:
		__push_error(desc, ["ifvi equality positive case fail"])
	
	GsomConsole.submit("ifvi test_console_ifvi == 3 inc test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 4:
		__push_ok(desc, ["ifvi equality negative case ok"])
	else:
		__push_error(desc, ["ifvi equality negative case fail"])
	
	GsomConsole.submit("ifvi test_console_ifvi > 3 dec test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 3:
		__push_ok(desc, ["ifvi greater positive case ok"])
	else:
		__push_error(desc, ["ifvi greater positive case fail"])
	
	GsomConsole.submit("ifvi test_console_ifvi > 3 dec test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 3:
		__push_ok(desc, ["ifvi greater negative case ok"])
	else:
		__push_error(desc, ["ifvi greater negative case fail"])
	
	GsomConsole.submit("ifvi test_console_ifvi < 4 inc test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 4:
		__push_ok(desc, ["ifvi greater positive case ok"])
	else:
		__push_error(desc, ["ifvi greater positive case fail"])
	
	GsomConsole.submit("ifvi test_console_ifvi < 4 inc test_console_ifvi")
	if GsomConsole.get_cvar("test_console_ifvi") == 4:
		__push_ok(desc, ["ifvi greater negative case ok"])
	else:
		__push_error(desc, ["ifvi greater negative case fail"])
	
	__flush(desc)

func __test_console_ifvv() -> void:
	var desc: Dictionary = __describe("Console Ifvv")
	
	GsomConsole.register_cvar("test_console_ifvv_1", 5.5)
	GsomConsole.register_cvar("test_console_ifvv_2", 5.5)
	
	GsomConsole.submit("ifvv test_console_ifvv_1 == test_console_ifvv_2 inc test_console_ifvv_1")
	if GsomConsole.get_cvar("test_console_ifvv_1") == 6.5:
		__push_ok(desc, ["ifvv equality positive case ok"])
	else:
		__push_error(desc, ["ifvv equality positive case fail"])
	
	GsomConsole.submit("ifvv test_console_ifvv_1 == test_console_ifvv_2 inc test_console_ifvv_1")
	if GsomConsole.get_cvar("test_console_ifvv_1") == 6.5:
		__push_ok(desc, ["ifvv equality negative case ok"])
	else:
		__push_error(desc, ["ifvv equality negative case fail"])
	
	GsomConsole.submit("ifvv test_console_ifvv_1 > test_console_ifvv_2 dec test_console_ifvv_1")
	if GsomConsole.get_cvar("test_console_ifvv_1") == 5.5:
		__push_ok(desc, ["ifvv greater positive case ok"])
	else:
		__push_error(desc, ["ifvv greater positive case fail"])
	
	GsomConsole.submit("ifvv test_console_ifvv_1 > test_console_ifvv_2 dec test_console_ifvv_1")
	if GsomConsole.get_cvar("test_console_ifvv_1") == 5.5:
		__push_ok(desc, ["ifvv greater negative case ok"])
	else:
		__push_error(desc, ["ifvv greater negative case fail"])
	
	GsomConsole.set_cvar("test_console_ifvv_2", 6.5)
	GsomConsole.submit("ifvv test_console_ifvv_1 < test_console_ifvv_2 dec test_console_ifvv_2")
	if GsomConsole.get_cvar("test_console_ifvv_2") == 5.5:
		__push_ok(desc, ["ifvv greater positive case ok"])
	else:
		__push_error(desc, ["ifvv greater positive case fail"])
	
	GsomConsole.submit("ifvv test_console_ifvv_1 < test_console_ifvv_2 inc test_console_ifvv_1")
	if GsomConsole.get_cvar("test_console_ifvv_1") == 5.5:
		__push_ok(desc, ["ifvv greater negative case ok"])
	else:
		__push_error(desc, ["ifvv greater negative case fail"])
	
	__flush(desc)

func __test_console_inc() -> void:
	var desc: Dictionary = __describe("Console Inc")
	
	GsomConsole.register_cvar("test_console_inc_bool", false)
	GsomConsole.register_cvar("test_console_inc_int", 3)
	GsomConsole.register_cvar("test_console_inc_float", -8.3)
	GsomConsole.register_cvar("test_console_inc_str", "read")
	
	GsomConsole.submit("inc test_console_inc_bool")
	if GsomConsole.get_cvar("test_console_inc_bool") == true:
		__push_ok(desc, ["bool variable has been incremented"])
	else:
		__push_error(desc, ["bool variable not incremented"])
	
	GsomConsole.submit("inc test_console_inc_int")
	if GsomConsole.get_cvar("test_console_inc_int") == 4:
		__push_ok(desc, ["int variable has been incremented"])
	else:
		__push_error(desc, ["int variable not incremented"])
	
	GsomConsole.submit("inc test_console_inc_float")
	if GsomConsole.get_cvar("test_console_inc_float") == -7.3:
		__push_ok(desc, ["float variable has been incremented"])
	else:
		__push_error(desc, [
			"float variable not incremented",
			str(GsomConsole.get_cvar("test_console_inc_float")),
		])
	
	GsomConsole.submit("inc test_console_inc_str y")
	if GsomConsole.get_cvar("test_console_inc_str") == "ready":
		__push_ok(desc, ["str variable has been incremented"])
	else:
		__push_error(desc, ["str variable not incremented"])
	
	__flush(desc)

func __test_console_dec() -> void:
	var desc: Dictionary = __describe("Console Dec")
	
	GsomConsole.register_cvar("test_console_dec_bool", true)
	GsomConsole.register_cvar("test_console_dec_int", 3)
	GsomConsole.register_cvar("test_console_dec_float", -8.3)
	GsomConsole.register_cvar("test_console_dec_str", "read")
	
	GsomConsole.submit("dec test_console_dec_bool")
	if GsomConsole.get_cvar("test_console_dec_bool") == false:
		__push_ok(desc, ["bool variable has been decremented"])
	else:
		__push_error(desc, ["bool variable not decremented"])
	
	GsomConsole.submit("dec test_console_dec_int")
	if GsomConsole.get_cvar("test_console_dec_int") == 2:
		__push_ok(desc, ["int variable has been decremented"])
	else:
		__push_error(desc, ["int variable not decremented"])
	
	GsomConsole.submit("dec test_console_dec_float")
	if GsomConsole.get_cvar("test_console_dec_float") == -9.3:
		__push_ok(desc, ["float variable has been decremented"])
	else:
		__push_error(desc, [
			"float variable not decremented",
			str(GsomConsole.get_cvar("test_console_dec_float")),
		])
	
	GsomConsole.submit("dec test_console_dec_str ad")
	if GsomConsole.get_cvar("test_console_dec_str") == "re":
		__push_ok(desc, ["str variable has been decremented"])
	else:
		__push_error(desc, ["str variable not decremented"])
	
	__flush(desc)


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
	var desc: Dictionary = __describe("Text Matcher")
	
	for matcher_case: Dictionary in __matcher_cases:
		var matched := GsomConsole.TextMatcher.new(matcher_case.text, matcher_case.available)
		if str(matched.matched) != str(matcher_case.expected):
			__push_error(desc, [
				"Text Match: `%s` %s" % [matcher_case.text, matcher_case.available],
				"%s (actual)" % str(matched.matched),
				"%s (expected)" % str(matcher_case.expected),
			])
		else:
			__push_ok(desc, [
				"Text Match: `%s` %s" % [matcher_case.text, matcher_case.available],
				"Matched: %s" % str(matched.matched),
			])
	
	__flush(desc)

#endregion
