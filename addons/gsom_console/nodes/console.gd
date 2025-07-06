extends Control

const __MIN_WIDTH: float = 480
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


var __wrapper_size := Vector2(__MIN_WIDTH, __MIN_HEIGHT):
	get:
		return get_parent().size
	set(v):
		get_parent().size = v

var __wrapper_wigth: float = __MIN_WIDTH:
	get:
		return __wrapper_size.x
	set(v):
		__wrapper_size.x = v

var __wrapper_height: float = __MIN_HEIGHT:
	get:
		return __wrapper_size.y
	set(v):
		__wrapper_size.y = v


var __view_size := Vector2(__MIN_WIDTH, __MIN_HEIGHT):
	get:
		return get_viewport().size


var __view_wigth: float = __MIN_WIDTH:
	get:
		return __view_size.x

var __view_height: float = __MIN_HEIGHT:
	get:
		return __view_size.y


@onready var __draggable: Control = $Draggable
@onready var __label_log: RichTextLabel = $Panel/ColumnMain/BgLog/LabelLog
@onready var __button_close: Button = $Panel/ColumnMain/RowTitle/ButtonClose
@onready var __button_submit: Button = $Panel/ColumnMain/RowInput/ButtonSubmit
@onready var __edit_cmd: LineEdit = $Panel/ColumnMain/RowInput/ContainerCmd/EditCmd
@onready var __container_hint: Control = $Panel/ColumnMain/BgLog/ContainerHint
@onready var __column_hint: Control = $Panel/ColumnMain/BgLog/ContainerHint/ContainerHintInner/ColumnHint
@onready var __resize_top: Control = $Resizers/ResizeTop
@onready var __resize_bottom: Control = $Resizers/ResizeBottom
@onready var __resize_left: Control = $Resizers/ResizeLeft
@onready var __resize_right: Control = $Resizers/ResizeRight

var __CommonLogic: GDScript = preload('../tools/common_ui.gd')
var __common_logic = null


func _ready() -> void:
	__common_logic = __CommonLogic.new(
		__label_log,
		__button_close,
		__button_submit,
		__edit_cmd,
		__container_hint,
		__column_hint,
	)
	
	__draggable.gui_input.connect(__handle_input_drag)
	__resize_top.gui_input.connect(__handle_input_resize_top)
	__resize_bottom.gui_input.connect(__handle_input_resize_bottom)
	__resize_left.gui_input.connect(__handle_input_resize_left)
	__resize_right.gui_input.connect(__handle_input_resize_right)

#region Drag Handlers

func __handle_input_drag(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		__handle_mouse_button_drag(event)
	elif event is InputEventMouseMotion:
		__handle_mouse_move_drag(event)


func __handle_mouse_button_drag(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if event.pressed:
		__is_drag = true
		__grab_pos_mouse = event.global_position - __wrapper_pos
	else:
		__is_drag = false


func __handle_mouse_move_drag(event: InputEventMouseMotion) -> void:
	if !__is_drag:
		return
		
	__wrapper_pos = event.global_position - __grab_pos_mouse

#endregion

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


func __handle_input_resize_top(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		__handle_mouse_button_resize(event)
	elif event is InputEventMouseMotion and __is_resize:
		__handle_mouse_move_resize_top(event)


func __handle_input_resize_bottom(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		__handle_mouse_button_resize(event)
	elif event is InputEventMouseMotion and __is_resize:
		__handle_mouse_move_resize_bottom(event)


func __handle_input_resize_left(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		__handle_mouse_button_resize(event)
	elif event is InputEventMouseMotion and __is_resize:
		__handle_mouse_move_resize_left(event)


func __handle_input_resize_right(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		__handle_mouse_button_resize(event)
	elif event is InputEventMouseMotion and __is_resize:
		__handle_mouse_move_resize_right(event)


func __handle_mouse_move_resize_top(event: InputEventMouseMotion) -> void:
	var dy: float = event.global_position.y - __grab_pos_mouse.y
	var new_y: float = clamp(__grab_pos_wrapper.y + dy, 0.0, __view_height)
	var new_h: float = __grab_size.y + (__grab_pos_mouse.y - new_y)
	if new_h < __MIN_HEIGHT:
		return
	
	__wrapper_pos.y = new_y
	__wrapper_height = new_h


func __handle_mouse_move_resize_bottom(event: InputEventMouseMotion) -> void:
	var dy: float = event.global_position.y - __grab_pos_mouse.y
	var new_h: float = __grab_size.y + dy
	if new_h < __MIN_HEIGHT or (new_h + __grab_pos_wrapper.y > __view_height):
		return
	
	__wrapper_height = new_h


func __handle_mouse_move_resize_left(event: InputEventMouseMotion) -> void:
	var dx: float = event.global_position.x - __grab_pos_mouse.x
	var new_x: float = clamp(__grab_pos_wrapper.x + dx, 0.0, __view_wigth)
	var new_w: float = __grab_size.x + (__grab_pos_mouse.x - new_x)
	if new_w < __MIN_WIDTH:
		return
	
	__wrapper_pos.x = new_x
	__wrapper_wigth = new_w


func __handle_mouse_move_resize_right(event: InputEventMouseMotion) -> void:
	var dx: float = event.global_position.x - __grab_pos_mouse.x
	var new_w: float = __grab_size.x + dx
	if new_w < __MIN_WIDTH or (new_w + __grab_pos_wrapper.x > __view_wigth):
		return
	
	__wrapper_wigth = new_w

#endregion
