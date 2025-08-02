@tool
extends Control

## The default UI for GsomConsole.
class_name GsomConsolePanel

# This wrapper is used to bypass the `add_custom_type` limitation
# that only allows adding scripts.
# The script immediatelly instantiates `__SceneConsole`,
# even in Editor - what you see is what you get.

var __blur: float = 0.6
## Background blur intensity. Blur is only visible while `color.a` is below 1.
@export_range(0.0, 1.0) var blur: float = 0.6:
	get:
		return __blur
	set(v):
		__blur = v
		__assign_blur()


var __color: Color = Color(0.25, 0.25, 0.25, 0.7)
## Panel background color. When alpha is 0 - only blur applied, if 1 no blur visible.
@export var color: Color = Color(0.25, 0.25, 0.25, 0.7):
	get:
		return __color
	set(v):
		__color = v
		__assign_color()


var __label_window: String = "Console"
## The window title displayed at the top left corner.
@export var label_window: String = "Console":
	get:
		return __label_window
	set(v):
		__label_window = v
		__assign_label_window()


var __label_submit: String = "submit"
## The label of "submit" button at the bottom right. 
@export var label_submit: String = "submit":
	get:
		return __label_submit
	set(v):
		__label_submit = v
		__assign_label_submit()


var __is_resize_enabled: bool = true
## Makes window borders draggable. 
@export var is_resize_enabled: bool = true:
	get:
		return __is_resize_enabled
	set(v):
		__is_resize_enabled = v
		__assign_is_resize_enabled()


var __is_draggable: bool = true
## Makes window panel draggable. 
@export var is_draggable: bool = true:
	get:
		return __is_draggable
	set(v):
		__is_draggable = v
		__assign_is_draggable()


var __is_disabled: bool = false
## Hides this console UI regardless of the singleton visibility state.
@export var is_disabled: bool = false:
	get:
		return __is_disabled
	set(v):
		__is_disabled = v
		__assign_is_disabled()


const __MIN_WIDTH: float = 480
const __MIN_HEIGHT: float = 320
const __PATH_BLUR: String = "Panel/Blur"
const __PATH_LABEL_TITLE: String = "Panel/ColumnMain/RowTitle/LabelTitle"
const __PATH_BUTTON_SUBMIT: String = "Panel/ColumnMain/RowInput/ButtonSubmit"
const __PATH_RESIZERS: String = "Resizers"
const __PATH_DRAGGABLE: String = "Draggable"

const __SceneConsole: PackedScene = preload("../nodes/console.tscn")
var __wnd: Control = null


func _ready() -> void:
	custom_minimum_size = Vector2(__MIN_WIDTH, __MIN_HEIGHT)
	
	__wnd = __SceneConsole.instantiate()
	add_child(__wnd)
	
	# Use duplicated material and shader to avoid changing the default from an instance
	var blur_panel: Control = __wnd.get_node(__PATH_BLUR)
	blur_panel.material = blur_panel.material.duplicate(true)
	
	if Engine.is_editor_hint():
		visible = true
	else:
		GsomConsole.connect("toggled", __handle_visibility)
		__handle_visibility(GsomConsole.is_visible)
	
	__assign_blur()
	__assign_color()
	__assign_label_window()
	__assign_label_submit()
	__assign_is_resize_enabled()
	__assign_is_draggable()
	__assign_is_disabled()


func __handle_visibility(new_is_visible: bool) -> void:
	if !Engine.is_editor_hint():
		visible = !is_disabled and new_is_visible

#region Property Helpers

func __assign_label_window() -> void:
	if __wnd:
		var label: Label = __wnd.get_node(__PATH_LABEL_TITLE)
		label.text = __label_window


func __assign_label_submit() -> void:
	if __wnd:
		var button: Button = __wnd.get_node(__PATH_BUTTON_SUBMIT)
		button.text = __label_submit


func __assign_blur() -> void:
	if __wnd:
		var blur_rect: ColorRect = __wnd.get_node(__PATH_BLUR)
		var mat: ShaderMaterial = blur_rect.material
		mat.set_shader_parameter("blur", __blur * 5.0)


func __assign_color() -> void:
	if __wnd:
		var blur_rect: ColorRect = __wnd.get_node(__PATH_BLUR)
		var mat: ShaderMaterial = blur_rect.material
		mat.set_shader_parameter("color", __color)


func __assign_is_resize_enabled() -> void:
	if __wnd:
		var resizers: Control = __wnd.get_node(__PATH_RESIZERS)
		resizers.visible = __is_resize_enabled


func __assign_is_draggable() -> void:
	if __wnd:
		var draggable: Control = __wnd.get_node(__PATH_DRAGGABLE)
		draggable.visible = __is_draggable


func __assign_is_disabled() -> void:
	if __wnd:
		__handle_visibility(GsomConsole.is_visible)

#endregion
