extends Control

@onready var __console_panel: GsomConsolePanel = $GsomConsolePanel
@onready var __plaque_panel: GsomPlaquePanel = $GsomPlaquePanel
@onready var __button_console: Button = $VBoxContainer/HBoxContainer/Console
@onready var __button_plaque: Button = $VBoxContainer/HBoxContainer/Plaque
@onready var __actor: ColorRect = $Area/Actor
@onready var __area: ColorRect = $Area


func _ready() -> void:
	GsomConsole.called_cmd.connect(__handle_commands)
	
	GsomConsole.register_action("move_up")
	GsomConsole.register_action("move_down")
	GsomConsole.register_action("move_left")
	GsomConsole.register_action("move_right")
	
	GsomConsole.register_cvar("test1", 1.0, "Test CVAR 1.")
	GsomConsole.register_cvar("test2", true, "Test CVAR 2.")
	GsomConsole.register_cvar("test3", 3, "Test CVAR 3.")
	GsomConsole.register_cvar("test4", "hello", "Test CVAR 4.")
	GsomConsole.register_cvar("test5", -10, "Test CVAR 5.")
	
	GsomConsole.register_cmd("recolor", "Changes the color of the example rectangle.")
	GsomConsole.register_cmd("do_something", "Test CMD.")
	
	GsomConsole.submit("exec preview")
	GsomConsole.log("Hello World.")
	GsomConsole.log("You can try [b]exec example[/b] (see res://example.cfg).")
	
	if __console_panel:
		__console_panel.is_disabled = !__button_console.button_pressed
		__button_console.toggled.connect(
			func (is_on: bool) -> void:
				__console_panel.is_disabled = !is_on
		)
	
	if __plaque_panel:
		__plaque_panel.is_disabled = !__button_plaque.button_pressed
		__button_plaque.toggled.connect(
			func (is_on: bool) -> void:
				__plaque_panel.is_disabled = !is_on
		)


func __handle_commands(cmd_name: String, args: PackedStringArray) -> void:
	if cmd_name == "do_something":
		prints("do_something:", args)
		GsomConsole.info("do_something: %s" % str(args))
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
