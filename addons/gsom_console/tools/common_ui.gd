extends Object

var _is_hint: bool = false
var _list_hint: PackedStringArray = []
var _is_history: bool = false
var _index: int = 0

var _label_log: RichTextLabel = null
var _button_close: Button = null
var _button_submit: Button = null
var _edit_cmd: LineEdit = null
var _container_hint: Control = null
var _column_hint: Control = null


func _init(
	label_log: RichTextLabel,
	button_close: Button,
	button_submit: Button,
	edit_cmd: LineEdit,
	container_hint: Control,
	column_hint: Control,
) -> void:
	_label_log = label_log
	_button_close = button_close
	_button_submit = button_submit
	_edit_cmd = edit_cmd
	_container_hint = container_hint
	_column_hint = column_hint
	
	GsomConsole.toggled.connect(_handle_visibility)
	_handle_visibility(GsomConsole.is_visible)
	
	GsomConsole.logged.connect(_handle_log_change)
	_handle_log_change()
	
	if _button_close:
		_button_close.pressed.connect(GsomConsole.hide)
	if _button_submit:
		_button_submit.pressed.connect(_handle_submit)
	
	if _edit_cmd:
		_edit_cmd.text_submitted.connect(_handle_submit)
		_edit_cmd.gui_input.connect(_handle_edit_keys)
		_edit_cmd.text_changed.connect(_handle_text_change)
		_handle_text_change(_edit_cmd.text)
	
	if _column_hint:
		for child: Button in _column_hint.get_children():
			child.pressed.connect(_handle_hint_button.bind(child))


#region Console Input Handlers

func _handle_visibility(is_visible: bool) -> void:
	if is_visible:
		if _edit_cmd:
			_edit_cmd.grab_focus()
	else:
		if _edit_cmd:
			_edit_cmd.text = ""
		_reset_hint_state()


func _handle_log_change(_text: String = "") -> void:
	if _label_log:
		_label_log.text = GsomConsole.log_text


func _handle_hint_button(sender: Button) -> void:
	_apply_hint(sender.text)


func _handle_text_change(text: String) -> void:
	if _button_submit:
		_button_submit.disabled = !text
	
	_is_history = false
	_index = 0
	
	if !text:
		if _container_hint:
			_container_hint.visible = false
		_is_hint = false
		_render_hints()
		return
	
	var match_list: PackedStringArray = GsomConsole.get_matches(text)
	if !match_list.size():
		return
	
	_list_hint = match_list.duplicate()
	if _container_hint:
		_container_hint.visible = true
	_render_hints()


func _handle_submit(_text: String = "") -> void:
	var cmd: String = _edit_cmd.text if _edit_cmd else ""
	
	if !_is_hint:
		_reset_hint_state()
		
		if !cmd:
			return
		
		if _edit_cmd:
			_edit_cmd.text = ""
		GsomConsole.submit(cmd)
		return
	
	_apply_from_list()


func _handle_edit_keys(event: InputEvent) -> void:
	if (
		Input.mouse_mode != Input.MOUSE_MODE_VISIBLE and
		Input.mouse_mode != Input.MOUSE_MODE_CONFINED
	):
		return
	
	if event is InputEventKey:
		_handle_key(event)


func _handle_key(event: InputEventKey) -> void:
	if (
		event.keycode == KEY_UP or
		event.keycode == KEY_DOWN or
		(_is_hint and event.keycode == KEY_ESCAPE)
	):
		if _edit_cmd:
			_edit_cmd.accept_event()
	
	if !event.is_pressed():
		if (_is_hint and event.keycode == KEY_ESCAPE):
			_reset_hint_state()
		return
	
	var cmd: String = _edit_cmd.text if _edit_cmd else ""
	if event.keycode == KEY_UP:
		if _container_hint and _container_hint.visible:
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
			if _container_hint:
				_container_hint.visible = true
			_is_hint = true
			_render_hints()
			return
		return
	
	if event.keycode == KEY_DOWN:
		if _container_hint and _container_hint.visible:
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
	if _container_hint:
		_container_hint.visible = false
	_is_history = false
	_is_hint = false
	_index = 0
	_list_hint = []
	_render_hints()


func _apply_hint(text: String) -> void:
	if _edit_cmd:
		_edit_cmd.text = text
		_edit_cmd.caret_column = text.length()
	_reset_hint_state()


func _render_hints() -> void:
	if !_container_hint or !_container_hint.visible:
		return
		
	var sub_range: Array[int] = _getSublist()
	var sublist: PackedStringArray = _list_hint.slice(sub_range[0], sub_range[1]) as PackedStringArray
	var sublen: int = sublist.size()
	var children: Array[Node] = _column_hint.get_children() if _column_hint else []
	var child_count: int = children.size()
	var list_len: int = _list_hint.size()
	var index_final: int = _get_positive_index()
	var text: String = _list_hint[index_final]
	
	for i: int in range(0, child_count):
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
