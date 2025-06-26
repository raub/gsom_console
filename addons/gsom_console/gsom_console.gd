@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("GsomConsole", "./gsom_console_autoload.gd")
	add_custom_type(
		"GsomConsolePanel",
		"Control", preload("./tools/console_wrap.gd"), preload("./tools/console.svg")
	)
	add_custom_type(
		"GsomPlaquePanel",
		"Control", preload("./tools/plaque_wrap.gd"), preload("./tools/console.svg")
	)


func _exit_tree() -> void:
	remove_autoload_singleton("GsomConsole")
	remove_custom_type("GsomConsolePanel")
	remove_custom_type("GsomPlaquePanel")
