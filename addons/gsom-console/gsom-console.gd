@tool
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("GsomConsole", "./gsom-console-autoload.gd");
	add_custom_type("GsomConsolePanel", "Control", preload("./ui/console-wrap.gd"), preload("./console.svg"));


func _exit_tree():
	remove_autoload_singleton("GsomConsole");
	remove_custom_type("GsomConsolePanel");
