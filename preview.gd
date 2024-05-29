extends Control


func _ready():
	InputMap.add_action("Console");
	var keyLquo = InputEventKey.new();
	keyLquo.keycode = KEY_QUOTELEFT;
	InputMap.action_add_event("Console", keyLquo);
	
	GsomConsole.registerCvar("test1", 1.0, "Test cvar 1.");
	GsomConsole.registerCvar("test2", 2.0, "Test cvar 2.");
	GsomConsole.registerCvar("test3", 3.0, "Test cvar 3.");
	GsomConsole.registerCvar("test4", 4.0, "Test cvar 4.");
	GsomConsole.registerCvar("test5", 5.0, "Test cvar 5.");
	GsomConsole.log("Use `help` to see available commands.");


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var keyEvent = event as InputEventKey;
		if keyEvent.is_action("Console") && Input.is_action_just_pressed("Console"):
			GsomConsole.toggle();
			accept_event();
