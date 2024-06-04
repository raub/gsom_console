extends Control


func _ready():
	InputMap.add_action("Console");
	var keyLquo = InputEventKey.new();
	keyLquo.keycode = KEY_QUOTELEFT;
	InputMap.action_add_event("Console", keyLquo);
	
	GsomConsole.registerCvar("test1", 1.0, "Test CVAR 1.");
	GsomConsole.registerCvar("test2", true, "Test CVAR 2.");
	GsomConsole.registerCvar("test3", 3, "Test CVAR 3.");
	GsomConsole.registerCvar("test4", "hello", "Test CVAR 4.");
	GsomConsole.registerCvar("test5", -10, "Test CVAR 5.");
	
	GsomConsole.log("Hello World.");


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var keyEvent = event as InputEventKey;
		if keyEvent.is_action("Console") && Input.is_action_just_pressed("Console"):
			GsomConsole.toggle();
			accept_event();
