extends RefCounted

var __is_hint: bool = false
var __list_hint: PackedStringArray = []
var __is_history: bool = false
var __index: int = 0

var __label_log: RichTextLabel = null
var __button_close: Button = null
var __button_submit: Button = null
var __edit_cmd: LineEdit = null
var __container_hint: Control = null
var __column_hint: Control = null


func _init(
	label_log: RichTextLabel,
	button_close: Button,
	button_submit: Button,
	edit_cmd: LineEdit,
	container_hint: Control,
	column_hint: Control,
) -> void:
	__label_log = label_log
	__button_close = button_close
	__button_submit = button_submit
	__edit_cmd = edit_cmd
	__container_hint = container_hint
	__column_hint = column_hint
	
	if Engine.is_editor_hint():
		return
	
	GsomConsole.toggled.connect(__handle_visibility)
	__handle_visibility(GsomConsole.is_visible)
	
	GsomConsole.logged.connect(__handle_log_change)
	__handle_log_change()
	
	if __button_close:
		__button_close.pressed.connect(GsomConsole.hide)
	if __button_submit:
		__button_submit.pressed.connect(__handle_submit)
	
	if __edit_cmd:
		__edit_cmd.text_submitted.connect(__handle_submit)
		__edit_cmd.gui_input.connect(__handle_edit_keys)
		__edit_cmd.text_changed.connect(__handle_text_change)
		__handle_text_change(__edit_cmd.text)
	
	if __column_hint:
		for child: Button in __column_hint.get_children():
			child.pressed.connect(__handle_hint_button.bind(child))


#region Console Input Handlers

func __handle_visibility(is_visible: bool) -> void:
	if is_visible:
		if __edit_cmd:
			__edit_cmd.grab_focus()
	else:
		if __edit_cmd:
			__edit_cmd.text = ""
		__reset_hint_state()


func __handle_log_change(_text: String = "") -> void:
	if __label_log:
		__label_log.text = GsomConsole.log_text


func __handle_hint_button(sender: Button) -> void:
	__apply_hint(sender.text)


func __handle_text_change(text: String) -> void:
	if __button_submit:
		__button_submit.disabled = !text
	
	__is_history = false
	__index = 0
	
	if !text:
		if __container_hint:
			__container_hint.visible = false
		__is_hint = false
		__render_hints()
		return
	
	var match_list: PackedStringArray = GsomConsole.get_matches(text)
	if !match_list.size():
		return
	
	__list_hint = match_list.duplicate()
	if __container_hint:
		__container_hint.visible = true
	__render_hints()


func __handle_submit(_text: String = "") -> void:
	var cmd: String = __edit_cmd.text if __edit_cmd else ""
	
	if !__is_hint:
		__reset_hint_state()
		
		if !cmd:
			return
		
		if __edit_cmd:
			__edit_cmd.text = ""
		GsomConsole.submit(cmd)
		return
	
	__apply_from_list()


func __handle_edit_keys(event: InputEvent) -> void:
	if (
		Input.mouse_mode != Input.MOUSE_MODE_VISIBLE and
		Input.mouse_mode != Input.MOUSE_MODE_CONFINED
	):
		return
	
	if event is InputEventKey:
		__handle_key(event)


func __handle_key(event: InputEventKey) -> void:
	if (
		event.keycode == KEY_UP or
		event.keycode == KEY_DOWN or
		(__is_hint and event.keycode == KEY_ESCAPE)
	):
		if __edit_cmd:
			__edit_cmd.accept_event()
	
	if !event.is_pressed():
		if (__is_hint and event.keycode == KEY_ESCAPE):
			__reset_hint_state()
		return
	
	var cmd: String = __edit_cmd.text if __edit_cmd else ""
	if event.keycode == KEY_UP:
		if __container_hint and __container_hint.visible:
			if __is_hint:
				__index += 1
			else:
				__is_hint = true
				__index = 0
			__render_hints()
			return
		
		if !cmd:
			if !GsomConsole.history.size():
				return
			__list_hint = GsomConsole.history.duplicate()
			__list_hint.reverse()
			__is_history = true
			__index = 0
			if __container_hint:
				__container_hint.visible = true
			__is_hint = true
			__render_hints()
			return
		return
	
	if event.keycode == KEY_DOWN:
		if __container_hint and __container_hint.visible:
			if __is_hint:
				__index -= 1
			else:
				__is_hint = true
				__index = 0
			__render_hints()
			return
		
		return

#endregion

#region Hints View

func __apply_from_list() -> void:
	var list_len: int = __list_hint.size()
	if !list_len:
		return
	var index_final: int = __get_positive__index()
	__apply_hint(__list_hint[index_final])


func __reset_hint_state() -> void:
	if __container_hint:
		__container_hint.visible = false
	__is_history = false
	__is_hint = false
	__index = 0
	__list_hint = []
	__render_hints()


func __apply_hint(text: String) -> void:
	if __edit_cmd:
		__edit_cmd.text = text
		__edit_cmd.caret_column = text.length()
	__reset_hint_state()


func __render_hints() -> void:
	if !__container_hint or !__container_hint.visible:
		return
		
	var sub_range: Array[int] = __get_sublist()
	var sublist: PackedStringArray = __list_hint.slice(sub_range[0], sub_range[1]) as PackedStringArray
	var sublen: int = sublist.size()
	var children: Array[Node] = __column_hint.get_children() if __column_hint else []
	var child_count: int = children.size()
	var list_len: int = __list_hint.size()
	var index_final: int = __get_positive__index()
	var text: String = __list_hint[index_final]
	
	for i: int in range(0, child_count):
		var idx: int = child_count - 1 - i
		children[idx].visible = i < sublen
		if i < sublen:
			children[idx].text = sublist[i]
			children[idx].flat = !__is_hint or (sub_range[0] + i != index_final)


# Convert `__index` to pozitive and keep within `__list_hint` bounds
func __get_positive__index() -> int:
	var list_len: int = __list_hint.size()
	return ((__index % list_len) + list_len) % list_len


# Calculate start and end indices of sublist to render
# Returns pair as array: [start__index, end__index]
func __get_sublist() -> Array[int]:
	var list_len: int = __list_hint.size()
	if list_len < 5:
		return [0, list_len]
	
	var index_final: int = __get_positive__index()
	if index_final < 3:
		return [0, 4]
	
	var index_last: int = list_len - 1
	var end_at: int = min(index_final + 2, list_len)
	var start_at: int = end_at - 4
	
	return [start_at, end_at]

#endregion
