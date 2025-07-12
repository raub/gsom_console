extends Control

const __IS_VERBOSE: bool = false

@onready var __label = $ScrollContainer/RichTextLabel

func _ready() -> void:
	__test_ast_valid()
	__test_ast_invalid()
	__test_console_help()
	__test_console_alias()
	__test_console_echo()
	__test_console_exec()
	__test_console_wait()
	__test_text_matcher()

#region Test Helpers

func __describe(test_name: String) -> Dictionary:
	return {
		"__name": test_name,
		"__has_error": false,
		"__verbose_text": "\n[b]%s[/b]\n\n" % test_name,
	}

func __push_error(desc: Dictionary, text: Array[String]) -> void:
	desc.__has_error = true
	desc.__verbose_text += "\t❌ %s\n\n" % "\n\t\t↳ ".join(text)

func __push_ok(desc: Dictionary, text: Array[String]) -> void:
	desc.__verbose_text += "\t✅ %s\n\n" % "\n\t\t↳ ".join(text)

func __flush(desc: Dictionary) -> void:
	if desc.__has_error or __IS_VERBOSE:
		__label.text += desc.__verbose_text
	else:
		__label.text += "\n[b]✅ %s Ok[/b]\n" % desc.__name

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
	
	GsomConsole.submit("echo test wait 1;wait;echo test wait 2;wait;echo test wait 3")
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
