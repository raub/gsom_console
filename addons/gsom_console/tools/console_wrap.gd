@tool
extends Control

## The default UI for GsomConsole.
class_name GsomConsolePanel

# This wrapper is used to bypass the `add_custom_type` limitation that only allows adding scripts.
# The script immediatelly instantiates `_SceneConsole`, even in Editor - what you see is what you get.

const _MIN_WIDTH: float = 480
const _MIN_HEIGHT: float = 320

const _SceneConsole: PackedScene = preload("../nodes/console.tscn")
var _console_window: Control = null


var _blur: float = 0.5
## Background blur intensity. Blur is only visible while `color.a` is below 1.
@export_range(0.0, 1.0) var blur: float = 0.6:
	get:
		return _blur
	set(v):
		_blur = v
		_assign_blur()


var _color := Color(0.1, 0.1, 0.1, 0.4)
## Panel background color. When alpha is 0 - only blur applied, if 1 no blur visible.
@export var color: Color = Color(0.1, 0.1, 0.1, 0.4):
	get:
		return _color
	set(v):
		_color = v
		_assign_color()


var _label_window := "Console"
## The window title displayed at the top left corner.
@export var label_window: String = "Console":
	get:
		return _label_window
	set(v):
		_label_window = v
		_assign_label_window()


var _label_submit := "submit"
## The label of "submit" button at the bottom right. 
@export var label_submit: String = "submit":
	get:
		return _label_submit
	set(v):
		_label_submit = v
		_assign_label_submit()


var _is_resize_enabled := true
## Makes window borders draggable. 
@export var is_resize_enabled: bool = true:
	get:
		return _is_resize_enabled
	set(v):
		_is_resize_enabled = v
		_assign_is_resize_enabled()


var _is_draggable := true
## Makes window panel draggable. 
@export var is_draggable: bool = true:
	get:
		return _is_draggable
	set(v):
		_is_draggable = v
		_assign_is_draggable()


func _ready() -> void:
	custom_minimum_size = Vector2(_MIN_WIDTH, _MIN_HEIGHT)
	_console_window = _SceneConsole.instantiate()
	add_child(_console_window)
	
	# Use duplicated material and shader to avoid changing the default from an instance
	var blur_panel: Control = _console_window.get_node("Panel/Blur")
	blur_panel.material = blur_panel.material.duplicate(true)
	
	_assign_blur()
	_assign_color()
	_assign_label_window()
	_assign_label_submit()
	_assign_is_resize_enabled()
	_assign_is_draggable()


#region Property Helpers

func _assign_label_window() -> void:
	if _console_window:
		_console_window.get_node("Panel/ColumnMain/RowTitle/LabelTitle").text = _label_window


func _assign_label_submit() -> void:
	if _console_window:
		_console_window.get_node("Panel/ColumnMain/RowInput/ButtonSubmit").text = _label_submit


func _assign_blur() -> void:
	if _console_window:
		_console_window.get_node("Panel/Blur").material.set_shader_parameter("blur", _blur * 5.0)


func _assign_color() -> void:
	if _console_window:
		_console_window.get_node("Panel/Blur").material.set_shader_parameter("color", _color)


func _assign_is_resize_enabled() -> void:
	if _console_window:
		_console_window.get_node("Resizers").visible = _is_resize_enabled


func _assign_is_draggable() -> void:
	if _console_window:
		_console_window.get_node("Draggable").visible = _is_draggable

#endregion
