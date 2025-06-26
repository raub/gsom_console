@tool
extends Control

## The default UI for GsomConsole.
class_name GsomPlaquePanel

# This wrapper is used to bypass the `add_custom_type` limitation that only allows adding scripts.
# The script immediatelly instantiates `_SceneConsole`, even in Editor - what you see is what you get.

const _MIN_HEIGHT: float = 320

const _SceneConsole: PackedScene = preload("../nodes/plaque.tscn")
var _plaque_window: Control = null


var _blur: float = 0.6
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


var _is_disabled := true
## Makes window panel disabled. 
@export var is_disabled: bool = true:
	get:
		return _is_disabled
	set(v):
		_is_disabled = v
		_assign_is_disabled()


# HACK: must be deferred after _ready, see https://github.com/godotengine/godot/issues/67161
func _deferred_layout() -> void:
	set_anchors_and_offsets_preset(LayoutPreset.PRESET_TOP_WIDE, LayoutPresetMode.PRESET_MODE_KEEP_HEIGHT)
	set_anchor_and_offset(SIDE_RIGHT, 1.0, 0.0)


func _ready() -> void:
	custom_minimum_size = Vector2(0, _MIN_HEIGHT)
	
	_plaque_window = _SceneConsole.instantiate()
	add_child(_plaque_window)
	
	if Engine.is_editor_hint():
		visible = true
	else:
		GsomConsole.connect("toggled", _handle_visibility)
		_handle_visibility(GsomConsole.is_visible)
	
	# Use duplicated material and shader to avoid changing the default from an instance
	var blur_panel: Control = _plaque_window.get_node("Panel/Blur")
	blur_panel.material = blur_panel.material.duplicate(true)
	
	_assign_blur()
	_assign_color()
	_assign_label_submit()
	_assign_is_resize_enabled()
	_assign_is_disabled()
	
	call_deferred("_deferred_layout")


func _handle_visibility(is_visible: bool) -> void:
	if !Engine.is_editor_hint():
		visible = !is_disabled and is_visible

#region Property Helpers

func _assign_label_submit() -> void:
	if _plaque_window:
		_plaque_window.get_node("Panel/ColumnMain/RowInput/ButtonSubmit").text = _label_submit


func _assign_blur() -> void:
	if _plaque_window:
		_plaque_window.get_node("Panel/Blur").material.set_shader_parameter("blur", _blur * 5.0)


func _assign_color() -> void:
	if _plaque_window:
		_plaque_window.get_node("Panel/Blur").material.set_shader_parameter("color", _color)


func _assign_is_resize_enabled() -> void:
	if _plaque_window:
		_plaque_window.get_node("Resizers").visible = _is_resize_enabled


func _assign_is_disabled() -> void:
	if _plaque_window:
		_handle_visibility(GsomConsole.is_visible)

#endregion
