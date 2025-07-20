extends RefCounted

var __is_listening: bool = true
## Is the input manager grabbing input events (automatically) right now
@export var is_listening: bool = true:
	get:
		return __is_listening
	set(v):
		__is_listening = v


 # A ret*rded way of doing things, but well
const key_list: Array[Key] = [
	KEY_ESCAPE, KEY_TAB, KEY_BACKSPACE, KEY_ENTER,
	KEY_KP_ENTER, KEY_INSERT, KEY_DELETE, KEY_PAUSE,
	KEY_HOME, KEY_END, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN,
	KEY_PAGEUP, KEY_PAGEDOWN, KEY_SHIFT, KEY_CTRL, KEY_ALT,
	KEY_CAPSLOCK, KEY_NUMLOCK, KEY_F1, KEY_F2, KEY_F3,
	KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12,
	KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT, KEY_KP_PERIOD,
	KEY_KP_ADD, KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5,
	KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_MENU,
	KEY_BACK, KEY_FORWARD, KEY_SPACE, KEY_APOSTROPHE,
	KEY_COMMA, KEY_MINUS, KEY_PERIOD, KEY_SLASH,
	KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
	KEY_SEMICOLON, KEY_EQUAL, KEY_A, KEY_B, KEY_C,
	KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J, KEY_K, KEY_L, KEY_M,
	KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T, KEY_U, KEY_V, KEY_W,
	KEY_X, KEY_Y, KEY_Z, KEY_BRACKETLEFT, KEY_BACKSLASH, KEY_BRACKETRIGHT,
	KEY_QUOTELEFT, KEY_ASCIITILDE,
]

const mouse_list: Array[MouseButton] = [
	MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE,
	MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
	MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
	MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2, 
]

var joy_list: Array[JoyButton] = [
	JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_BACK, JOY_BUTTON_GUIDE, JOY_BUTTON_START,
	JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK,
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
	JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_MISC1, JOY_BUTTON_TOUCHPAD, 
	JOY_BUTTON_PADDLE1, JOY_BUTTON_PADDLE2,
	JOY_BUTTON_PADDLE3, JOY_BUTTON_PADDLE4,
]

var __key_to_label: Dictionary[int, String] = {}
var __key_to_name: Dictionary[int, String] = {}
var __mouse_to_label: Dictionary[int, String] = {}
var __mouse_to_name: Dictionary[int, String] = {}
var __joy_to_label: Dictionary[int, String] = {}
var __joy_to_name: Dictionary[int, String] = {}
var __name_to_event: Dictionary[String, InputEvent] = {}
var __name_to_state: Dictionary[String, bool] = {}


func _init() -> void:
	reset()


func reset() -> void:
	__key_to_label = {}
	__key_to_name = {}
	__mouse_to_label = {}
	__mouse_to_name = {}
	__joy_to_label = {}
	__joy_to_name = {}
	__name_to_event = {}
	__name_to_state = {}
	
	for key: Key in key_list:
		__assign_key(key)
	for button: MouseButton in mouse_list:
		__assign_mouse(button)
	for button: JoyButton in joy_list:
		__assign_joystick(button)


func get_event_by_name(event_name: String) -> InputEvent:
	if !__name_to_event.has(event_name):
		var e := InputEventKey.new()
		e.keycode = KEY_NONE
		return e
	return __name_to_event[event_name]


func get_name_by_event(e: InputEvent) -> String:
	if e is InputEventKey:
		var e_key := e as InputEventKey
		if __key_to_name.has(e_key.keycode):
			return __key_to_name[e_key.keycode]
		return ""
	
	if e is InputEventMouseButton:
		var e_button := e as InputEventMouseButton
		if __mouse_to_name.has(e_button.button_index):
			return __mouse_to_name[e_button.button_index]
		return ""
	
	if e is InputEventJoypadButton:
		var e_button := e as InputEventJoypadButton
		if __joy_to_name.has(e_button.button_index):
			return __joy_to_name[e_button.button_index]
		return ""
	
	return ""


func get_label_by_name(event_name: String) -> String:
	if !__name_to_event.has(event_name):
		return ""
	return get_name_by_event(__name_to_event[event_name])


func get_state_by_name(event_name: String) -> bool:
	if !__name_to_state.has(event_name):
		return false
	return __name_to_state[event_name]


func set_state_by_name(event_name: String, event_state: bool) -> void:
	if !__name_to_state.has(event_name):
		return
	__name_to_state[event_name] = event_state


var __label_regex: RegEx = null
func __get_name_from_label(key_label: String) -> String:
	if !__label_regex:
		__label_regex = RegEx.new()
		__label_regex.compile("([a-z])([A-Z0-9])")
	return __label_regex.sub(key_label.replace(' ', '_'), "$1_$2", true).to_lower()


func __assign_key(key: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	var key_label := e.as_text_keycode()
	var key_name := __get_name_from_label(key_label)
	__key_to_label[key] = key_label
	__key_to_name[key] = key_name
	__name_to_event[key_name] = e
	__name_to_state[key_name] = false


func __assign_mouse(button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	var button_label := e.as_text()
	var button_name := __get_name_from_label(button_label)
	button_name = button_name.replace("_button", "").replace("mouse_", "")
	__mouse_to_label[button] = button_label
	__mouse_to_name[button] = button_name
	__name_to_event[button_name] = e
	__name_to_state[button_name] = false


func __assign_joystick(button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	var button_label := "Joystick %s" % button
	var button_name := __get_name_from_label(button_label)
	__joy_to_label[button] = button_label
	__joy_to_name[button] = button_name
	__name_to_event[button_name] = e
	__name_to_state[button_name] = false
