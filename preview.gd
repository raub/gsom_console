extends Control

@onready var _consolePanel: GsomConsolePanel = $GsomConsolePanel
@onready var _plaquePanel: GsomPlaquePanel = $GsomPlaquePanel
@onready var _buttonConsole: Button = $VBoxContainer/HBoxContainer/Console
@onready var _buttonPlaque: Button = $VBoxContainer/HBoxContainer/Plaque


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
	
	_consolePanel.is_disabled = !_buttonConsole.button_pressed
	_buttonConsole.toggled.connect(
		func (is_on: bool) -> void:
			_consolePanel.is_disabled = !is_on
	)
	
	_plaquePanel.is_disabled = !_buttonPlaque.button_pressed
	_buttonPlaque.toggled.connect(
		func (is_on: bool) -> void:
			_plaquePanel.is_disabled = !is_on
	)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.is_action("Console") and Input.is_action_just_pressed("Console"):
			GsomConsole.toggle()
			accept_event()
