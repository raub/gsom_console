@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("GsomConsole", "./gsom-console-autoload.gd")
	add_custom_type(
		"GsomConsolePanel", "Control", preload("./tools/console-wrap.gd"), preload("./tools/console.svg")
	)


func _exit_tree() -> void:
	remove_autoload_singleton("GsomConsole")
	remove_custom_type("GsomConsolePanel")
