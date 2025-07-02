extends Control

const _MIN_WIDTH: float = 480
const _MIN_HEIGHT: float = 320

var _is_drag: bool = false
var _is_resize: bool = false
var _grab_pos_mouse := Vector2()
var _grab_pos_wrapper := Vector2()
var _grab_size := Vector2()


var _wrapper_pos := Vector2.ZERO:
	get:
		return get_parent().position
	set(v):
		get_parent().position = v


var _wrapper_size := Vector2(_MIN_WIDTH, _MIN_HEIGHT):
	get:
		return get_parent().size
	set(v):
		get_parent().size = v

var _wrapper_wigth: float = _MIN_WIDTH:
	get:
		return _wrapper_size.x
	set(v):
		_wrapper_size.x = v

var _wrapper_height: float = _MIN_HEIGHT:
	get:
		return _wrapper_size.y
	set(v):
		_wrapper_size.y = v


var _view_size := Vector2(_MIN_WIDTH, _MIN_HEIGHT):
	get:
		return get_viewport().size


var _viewWigth: float = _MIN_WIDTH:
	get:
		return _view_size.x

var _viewHeight: float = _MIN_HEIGHT:
	get:
		return _view_size.y


@onready var _draggable: Control = $Draggable
@onready var _blur: Control = $Panel/Blur
@onready var _label_log: RichTextLabel = $Panel/ColumnMain/BgLog/LabelLog
@onready var _button_close: Button = $Panel/ColumnMain/RowTitle/ButtonClose
@onready var _button_submit: Button = $Panel/ColumnMain/RowInput/ButtonSubmit
@onready var _edit_cmd: LineEdit = $Panel/ColumnMain/RowInput/ContainerCmd/EditCmd
@onready var _container_hint: Control = $Panel/ColumnMain/BgLog/ContainerHint
@onready var _column_hint: Control = $Panel/ColumnMain/BgLog/ContainerHint/ContainerHintInner/ColumnHint
@onready var _resize_top: Control = $Resizers/ResizeTop
@onready var _resize_bottom: Control = $Resizers/ResizeBottom
@onready var _resize_left: Control = $Resizers/ResizeLeft
@onready var _resize_right: Control = $Resizers/ResizeRight

var CommonLogic: GDScript = preload('../tools/common_ui.gd')
var _common_logic = null

func _ready() -> void:
	_common_logic = CommonLogic.new(
		_label_log,
		_button_close,
		_button_submit,
		_edit_cmd,
		_container_hint,
		_column_hint,
	)
	
	_draggable.gui_input.connect(_handle_input_drag)
	_resize_top.gui_input.connect(_handle_input_resize_top)
	_resize_bottom.gui_input.connect(_handle_input_resize_bottom)
	_resize_left.gui_input.connect(_handle_input_resize_left)
	_resize_right.gui_input.connect(_handle_input_resize_right)

#region Drag Handlers

func _handle_input_drag(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button_drag(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_move_drag(event)


func _handle_mouse_button_drag(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if event.pressed:
		_is_drag = true
		_grab_pos_mouse = event.global_position - _wrapper_pos
	else:
		_is_drag = false


func _handle_mouse_move_drag(event: InputEventMouseMotion) -> void:
	if !_is_drag:
		return
		
	_wrapper_pos = event.global_position - _grab_pos_mouse

#endregion

#region Resize Handlers

func _handle_mouse_button_resize(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if event.pressed:
		_is_resize = true
		_grab_size = _wrapper_size
		_grab_pos_wrapper = _wrapper_pos
		_grab_pos_mouse = event.global_position
	else:
		_is_resize = false


func _handle_input_resize_top(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button_resize(event)
	elif event is InputEventMouseMotion and _is_resize:
		_handle_mouse_move_resize_top(event)


func _handle_input_resize_bottom(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button_resize(event)
	elif event is InputEventMouseMotion and _is_resize:
		_handle_mouse_move_resize_bottom(event)


func _handle_input_resize_left(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button_resize(event)
	elif event is InputEventMouseMotion and _is_resize:
		_handle_mouse_move_resize_left(event)


func _handle_input_resize_right(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button_resize(event)
	elif event is InputEventMouseMotion and _is_resize:
		_handle_mouse_move_resize_right(event)


func _handle_mouse_move_resize_top(event: InputEventMouseMotion) -> void:
	var dy: float = event.global_position.y - _grab_pos_mouse.y
	var new_y: float = clamp(_grab_pos_wrapper.y + dy, 0.0, _viewHeight)
	var new_h: float = _grab_size.y + (_grab_pos_mouse.y - new_y)
	if new_h < _MIN_HEIGHT:
		return
	
	_wrapper_pos.y = new_y
	_wrapper_height = new_h


func _handle_mouse_move_resize_bottom(event: InputEventMouseMotion) -> void:
	var dy: float = event.global_position.y - _grab_pos_mouse.y
	var new_h: float = _grab_size.y + dy
	if new_h < _MIN_HEIGHT or (new_h + _grab_pos_wrapper.y > _viewHeight):
		return
	
	_wrapper_height = new_h


func _handle_mouse_move_resize_left(event: InputEventMouseMotion) -> void:
	var dx: float = event.global_position.x - _grab_pos_mouse.x
	var new_x: float = clamp(_grab_pos_wrapper.x + dx, 0.0, _viewWigth)
	var new_w: float = _grab_size.x + (_grab_pos_mouse.x - new_x)
	if new_w < _MIN_WIDTH:
		return
	
	_wrapper_pos.x = new_x
	_wrapper_wigth = new_w


func _handle_mouse_move_resize_right(event: InputEventMouseMotion) -> void:
	var dx: float = event.global_position.x - _grab_pos_mouse.x
	var new_w: float = _grab_size.x + dx
	if new_w < _MIN_WIDTH or (new_w + _grab_pos_wrapper.x > _viewWigth):
		return
	
	_wrapper_wigth = new_w

#endregion
