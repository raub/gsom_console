extends Control

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


var _wrapper_size := Vector2(0, _MIN_HEIGHT):
	get:
		return get_parent().size
	set(v):
		get_parent().size = v

var _wrapper_wigth: float = 0:
	get:
		return _wrapper_size.x
	set(v):
		_wrapper_size.x = v

var _wrapper_height: float = _MIN_HEIGHT:
	get:
		return _wrapper_size.y
	set(v):
		_wrapper_size.y = v


var _view_size := Vector2(0, _MIN_HEIGHT):
	get:
		return get_viewport().size


var _viewWigth: float = 0:
	get:
		return _view_size.x

var _viewHeight: float = _MIN_HEIGHT:
	get:
		return _view_size.y


@onready var _blur: Control = $Panel/Blur
@onready var _label_log: RichTextLabel = $Panel/ColumnMain/BgLog/LabelLog
@onready var _button_close: Button = $Panel/ColumnMain/RowInput/ButtonClose
@onready var _button_submit: Button = $Panel/ColumnMain/RowInput/ButtonSubmit
@onready var _edit_cmd: LineEdit = $Panel/ColumnMain/RowInput/ContainerCmd/EditCmd
@onready var _container_hint: Control = $Panel/ColumnMain/BgLog/ContainerHint
@onready var _column_hint: Control = $Panel/ColumnMain/BgLog/ContainerHint/ContainerHintInner/ColumnHint
@onready var _resize_bottom: Control = $Resizers/ResizeBottom

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
	
	_resize_bottom.gui_input.connect(_handle_input_resize_bottom)

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


func _handle_input_resize_bottom(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button_resize(event)
	elif event is InputEventMouseMotion and _is_resize:
		_handle_mouse_move_resize_bottom(event)


func _handle_mouse_move_resize_bottom(event: InputEventMouseMotion) -> void:
	var dy: float = event.global_position.y - _grab_pos_mouse.y
	var new_h: float = _grab_size.y + dy
	if new_h < _MIN_HEIGHT or (new_h + _grab_pos_wrapper.y > _viewHeight):
		return
	
	_wrapper_height = new_h

#endregion
