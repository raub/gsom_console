extends Control

const _MIN_WIDTH: float = 480
const _MIN_HEIGHT: float = 320

var _is_drag: bool = false
var _is_resize: bool = false
var _grab_pos_mouse := Vector2()
var _grab_pos_wrapper := Vector2()
var _grab_size := Vector2()
var _is_hint: bool = false
var _list_hint: PackedStringArray = []
var _is_history: bool = false
var _index: int = 0


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


func _ready() -> void:
	_draggable.gui_input.connect(_handle_input_drag)
	_edit_cmd.gui_input.connect(_handle_edit_keys)
	_resize_top.gui_input.connect(_handle_input_resize_top)
	_resize_bottom.gui_input.connect(_handle_input_resize_bottom)
	_resize_left.gui_input.connect(_handle_input_resize_left)
	_resize_right.gui_input.connect(_handle_input_resize_right)
	
	GsomConsole.toggled.connect(_handle_visibility)
	_handle_visibility(GsomConsole.is_visible)
	
	GsomConsole.logged.connect(_handle_log_change)
	_handle_log_change()
	
	_button_close.pressed.connect(GsomConsole.hide)
	_button_submit.pressed.connect(_handle_submit)
	_edit_cmd.text_submitted.connect(_handle_submit)
	
	_edit_cmd.text_changed.connect(_handle_text_change)
	_handle_text_change(_edit_cmd.text)
	
	for child: Button in _column_hint.get_children():
		child.pressed.connect(_handle_hint_button.bind(child))


#region Console Input Handlers

func _handle_visibility(is_visible: bool) -> void:
	if is_visible:
		_edit_cmd.grab_focus()
	else:
		_edit_cmd.text = ""
		_reset_hint_state()


func _handle_log_change(_text: String = "") -> void:
	_label_log.text = GsomConsole.log_text


func _handle_hint_button(sender: Button) -> void:
	_apply_hint(sender.text)


func _handle_text_change(text: String) -> void:
	_button_submit.disabled = !text
	
	_is_history = false
	_index = 0
	
	if !text:
		_container_hint.visible = false
		_is_hint = false
		_render_hints()
		return
	
	var match_list: PackedStringArray = GsomConsole.get_matches(text)
	if !match_list.size():
		return
	
	_list_hint = match_list.duplicate()
	_container_hint.visible = true
	_render_hints()


func _handle_submit(_text: String = "") -> void:
	var cmd: String = _edit_cmd.text
	
	if !_is_hint:
		_reset_hint_state()
		
		if !cmd:
			return
		
		_edit_cmd.text = ""
		GsomConsole.submit(cmd)
		return
	
	_apply_from_list()


func _handle_edit_keys(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	elif event is InputEventKey:
		_handle_key(event)


func _handle_key(event: InputEventKey) -> void:
	if event.keycode == KEY_UP or event.keycode == KEY_DOWN or (_is_hint and event.keycode == KEY_ESCAPE):
		_edit_cmd.accept_event()
	
	if !event.is_pressed():
		if (_is_hint and event.keycode == KEY_ESCAPE):
			_reset_hint_state()
		return
	
	var cmd: String = _edit_cmd.text
	if event.keycode == KEY_UP:
		if _container_hint.visible:
			if _is_hint:
				_index += 1
			else:
				_is_hint = true
				_index = 0
			_render_hints()
			return
		
		if !cmd:
			if !GsomConsole.history.size():
				return
			_list_hint = GsomConsole.history.duplicate()
			_list_hint.reverse()
			_is_history = true
			_index = 0
			_container_hint.visible = true
			_is_hint = true
			_render_hints()
			return
		return
	
	if event.keycode == KEY_DOWN:
		if _container_hint.visible:
			if _is_hint:
				_index -= 1
			else:
				_is_hint = true
				_index = 0
			_render_hints()
			return
		
		return

#endregion

#region Hints View

func _apply_from_list() -> void:
	var list_len: int = _list_hint.size()
	if !list_len:
		return
	var index_final: int = _get_positive_index()
	_apply_hint(_list_hint[index_final])


func _reset_hint_state() -> void:
	_container_hint.visible = false
	_is_history = false
	_is_hint = false
	_index = 0
	_list_hint = []
	_render_hints()


func _apply_hint(text: String) -> void:
	_edit_cmd.text = text
	_edit_cmd.caret_column = text.length()
	_reset_hint_state()


func _render_hints() -> void:
	if !_container_hint.visible:
		return
		
	var sub_range: Array[int] = _getSublist()
	var sublist: PackedStringArray = _list_hint.slice(sub_range[0], sub_range[1]) as PackedStringArray
	var sublen: int = sublist.size()
	var children: Array[Node] = _column_hint.get_children()
	var child_count: int = children.size()
	var list_len: int = _list_hint.size()
	var index_final: int = _get_positive_index()
	var text: String = _list_hint[index_final]
	
	for i in range(0, child_count):
		var idx: int = child_count - 1 - i
		children[idx].visible = i < sublen
		if i < sublen:
			children[idx].text = sublist[i]
			children[idx].flat = !_is_hint or (sub_range[0] + i != index_final)


# Convert `_index` to pozitive and keep within `_list_hint` bounds
func _get_positive_index() -> int:
	var list_len: int = _list_hint.size()
	return ((_index % list_len) + list_len) % list_len


# Calculate start and end indices of sublist to render
# Returns pair as array: [start_index, end_index]
func _getSublist() -> Array[int]:
	var list_len: int = _list_hint.size()
	if list_len < 5:
		return [0, list_len]
	
	var index_final: int = _get_positive_index()
	if index_final < 3:
		return [0, 4]
	
	var index_last: int = list_len - 1
	var end_at: int = min(index_final + 2, list_len)
	var start_at: int = end_at - 4
	
	return [start_at, end_at]

#endregion

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
