extends Control

@onready var __consolePanel: GsomConsolePanel = $GsomConsolePanel
@onready var __plaquePanel: GsomPlaquePanel = $GsomPlaquePanel
@onready var __buttonConsole: Button = $VBoxContainer/HBoxContainer/Console
@onready var __buttonPlaque: Button = $VBoxContainer/HBoxContainer/Plaque


func _ready() -> void:
	InputMap.add_action("Console")
	var key_lquo := InputEventKey.new()
	key_lquo.keycode = KEY_QUOTELEFT
	InputMap.action_add_event("Console", key_lquo)
	
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


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.is_action("Console") and Input.is_action_just_pressed("Console"):
			GsomConsole.toggle()
			accept_event()
