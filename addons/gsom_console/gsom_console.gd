@tool
extends EditorPlugin


func _enable_plugin() -> void:
	add_autoload_singleton("GsomConsole", "./gsom_console_autoload.gd")


func _disable_plugin() -> void:
	remove_autoload_singleton("GsomConsole")


func _enter_tree() -> void:
	add_custom_type(
		"GsomConsolePanel",
		"Control", preload("./tools/console_wrap.gd"), preload("./tools/console.svg")
	)
	add_custom_type(
		"GsomPlaquePanel",
		"Control", preload("./tools/plaque_wrap.gd"), preload("./tools/console.svg")
	)


func _exit_tree() -> void:
	remove_custom_type("GsomConsolePanel")
	remove_custom_type("GsomPlaquePanel")
