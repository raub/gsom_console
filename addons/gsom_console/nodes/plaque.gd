extends Control

const __MIN_HEIGHT: float = 320

var __is_drag: bool = false
var __is_resize: bool = false
var __grab_pos_mouse := Vector2()
var __grab_pos_wrapper := Vector2()
var __grab_size := Vector2()


var __wrapper_pos := Vector2.ZERO:
	get:
		return get_parent().position
	set(v):
		get_parent().position = v


var __wrapper_size := Vector2(0, __MIN_HEIGHT):
	get:
		return get_parent().size
	set(v):
		get_parent().size = v

var __wrapper_height: float = __MIN_HEIGHT:
	get:
		return __wrapper_size.y
	set(v):
		__wrapper_size.y = v


var __view_size := Vector2(0, __MIN_HEIGHT):
	get:
		return get_viewport().size


var __view_height: float = __MIN_HEIGHT:
	get:
		return __view_size.y


@onready var __label_log: RichTextLabel = $Panel/ColumnMain/BgLog/LabelLog
@onready var __button_close: Button = $Panel/ColumnMain/RowInput/ButtonClose
@onready var __button_submit: Button = $Panel/ColumnMain/RowInput/ButtonSubmit
@onready var __edit_cmd: LineEdit = $Panel/ColumnMain/RowInput/ContainerCmd/EditCmd
@onready var __container_hint: Control = $Panel/ColumnMain/BgLog/ContainerHint
@onready var __column_hint: Control = $Panel/ColumnMain/BgLog/ContainerHint/ContainerHintInner/ColumnHint
@onready var __resize_bottom: Control = $Resizers/ResizeBottom

var __common_logic = null


func _ready() -> void:
	__common_logic = GsomConsole.CommonUi.new(
		__label_log,
		__button_close,
		__button_submit,
		__edit_cmd,
		__container_hint,
		__column_hint,
	)
	
	__resize_bottom.gui_input.connect(__handle_input_resize_bottom)

#region Resize Handlers

func __handle_mouse_button_resize(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if event.pressed:
		__is_resize = true
		__grab_size = __wrapper_size
		__grab_pos_wrapper = __wrapper_pos
		__grab_pos_mouse = event.global_position
	else:
		__is_resize = false


func __handle_input_resize_bottom(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		__handle_mouse_button_resize(event)
	elif event is InputEventMouseMotion and __is_resize:
		__handle_mouse_move_resize_bottom(event)


func __handle_mouse_move_resize_bottom(event: InputEventMouseMotion) -> void:
	var dy: float = event.global_position.y - __grab_pos_mouse.y
	var new_h: float = __grab_size.y + dy
	if new_h < __MIN_HEIGHT or (new_h + __grab_pos_wrapper.y > __view_height):
		return
	
	__wrapper_height = new_h

#endregion
