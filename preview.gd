extends Control

@onready var __consolePanel: GsomConsolePanel = $GsomConsolePanel
@onready var __plaquePanel: GsomPlaquePanel = $GsomPlaquePanel
@onready var __buttonConsole: Button = $VBoxContainer/HBoxContainer/Console
@onready var __buttonPlaque: Button = $VBoxContainer/HBoxContainer/Plaque
@onready var __actor: ColorRect = $Area/Actor
@onready var __area: ColorRect = $Area


func _ready() -> void:
	GsomConsole.register_action("move_up")
	GsomConsole.register_action("move_down")
	GsomConsole.register_action("move_left")
	GsomConsole.register_action("move_right")
	GsomConsole.register_cmd("recolor")
	
	GsomConsole.submit("exec preview")
	GsomConsole.called_cmd.connect(__handle_commands)
	
	GsomConsole.register_cvar("test1", 1.0, "Test CVAR 1.")
	GsomConsole.register_cvar("test2", true, "Test CVAR 2.")
	GsomConsole.register_cvar("test3", 3, "Test CVAR 3.")
	GsomConsole.register_cvar("test4", "hello", "Test CVAR 4.")
	GsomConsole.register_cvar("test5", -10, "Test CVAR 5.")
	
	GsomConsole.register_cmd("do_something", "Test CMD.")
	
	GsomConsole.called_cmd.connect(
		func (cmd_name: String, args: PackedStringArray) -> void:
			if cmd_name == "do_something":
				prints("do_something:", args)
				GsomConsole.info("do_something: %s" % str(args))
	)
	
	GsomConsole.log("Hello World.")
	GsomConsole.log("You can try [b]exec example[/b] (see res://example.cfg).")
	
	if __consolePanel:
		__consolePanel.is_disabled = !__buttonConsole.button_pressed
		__buttonConsole.toggled.connect(
			func (is_on: bool) -> void:
				__consolePanel.is_disabled = !is_on
		)
	
	if __plaquePanel:
		__plaquePanel.is_disabled = !__buttonPlaque.button_pressed
		__buttonPlaque.toggled.connect(
			func (is_on: bool) -> void:
				__plaquePanel.is_disabled = !is_on
		)


func __handle_commands(cmd_name: String, args: PackedStringArray) -> void:
	prints("cmd", cmd_name, args)
	if cmd_name == "recolor":
		if args.size() < 1:
			return
		__actor.color = Color(args[0])


func _process(delta: float) -> void:
	var dir := Vector2()
	dir.x += 1 if GsomConsole.read_action("move_right") else 0
	dir.x -= 1 if GsomConsole.read_action("move_left") else 0
	dir.y += 1 if GsomConsole.read_action("move_down") else 0
	dir.y -= 1 if GsomConsole.read_action("move_up") else 0
	
	var new_pos := __actor.position + dir.normalized() * delta * 100
	
	__actor.position = new_pos.clamp(Vector2(), __area.size - __actor.size)


func _unhandled_input(event: InputEvent) -> void:
	GsomConsole.handle_input(event)
