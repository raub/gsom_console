extends Control


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
	
	GsomConsole.log("Hello World.")


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.is_action("Console") and Input.is_action_just_pressed("Console"):
			GsomConsole.toggle()
			accept_event()
