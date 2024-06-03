extends Control

@onready var _panel: Control = $Panel;
@onready var _blur: Control = $Panel/Blur;
@onready var _labelLog: RichTextLabel = $Panel/ColumnMain/BgLog/LabelLog;
@onready var _buttonClose: Button = $Panel/ColumnMain/RowTitle/ButtonClose;
@onready var _buttonSubmit: Button = $Panel/ColumnMain/RowInput/ButtonSubmit;
@onready var _editCmd: LineEdit = $Panel/ColumnMain/RowInput/ContainerCmd/EditCmd;
@onready var _containerHint = $Panel/ColumnMain/BgLog/ContainerHint;
@onready var _columnHint = $Panel/ColumnMain/BgLog/ContainerHint/ContainerHintInner/ColumnHint;

var _isDrag: bool = false;
var _grabPos: Vector2 = Vector2();
var _isHint: bool = false;
var _listHint: Array = [];
var _isHistory: bool = false;
var _index: int = 0;


func _ready() -> void:
	self.visible = GsomConsole.isVisible;
	_panel.gui_input.connect(_handleInput);
	_editCmd.gui_input.connect(_handleEditKeys);
	
	GsomConsole.onToggle.connect(
		func (isVisible: bool) -> void:
			self.visible = isVisible;
			if isVisible:
				_editCmd.grab_focus();
			else:
				_editCmd.text = "";
				_resetHintState();
	);
	
	GsomConsole.onLog.connect(
		func (text: String) -> void:
			_labelLog.text += text + "\n";
	);
	
	_buttonClose.pressed.connect(GsomConsole.hide);
	_buttonSubmit.pressed.connect(_handleSubmit);
	_editCmd.text_submitted.connect(
		func (_text: String) -> void:
			_handleSubmit();
	);
	
	_editCmd.text_changed.connect(_handleTextChange);
	_handleTextChange(_editCmd.text);
	
	for c: Button in _columnHint.get_children():
		c.pressed.connect(_handleHintButton.bind(c));


func _handleHintButton(sender: Button) -> void:
	_applyHint(sender.text);


func _handleTextChange(text: String) -> void:
	_buttonSubmit.disabled = !text;
	
	_isHistory = false;
	_index = 0;
	
	if !text:
		_containerHint.visible = false;
		_isHint = false;
		_renderHints();
		return;
	
	var matchList: Array = GsomConsole.getMatches(text);
	if !matchList.size():
		return;
	
	_listHint = matchList.duplicate();
	_containerHint.visible = true;
	_renderHints();


func _renderHints() -> void:
	if !_containerHint.visible:
		return;
		
	var subRange: Array[int] = _getSublist();
	var sublist: Array = _listHint.slice(subRange[0], subRange[1]);
	var sublen: int = sublist.size();
	var children: Array[Node] = _columnHint.get_children();
	var childcount: int = children.size();
	var listLen: int = _listHint.size();
	var indexFinal: int = _getPositiveIndex();
	var text: String = _listHint[indexFinal];
	
	for i in range(0, childcount):
		var idx: int = childcount - 1 - i;
		children[idx].visible = i < sublen;
		if i < sublen:
			children[idx].text = sublist[i];
			children[idx].flat = !_isHint || (subRange[0] + i != indexFinal);


func _handleSubmit() -> void:
	var cmd: String = _editCmd.text;
	
	if !_isHint:
		_resetHintState();
		
		if !cmd:
			return;
		
		_editCmd.text = "";
		GsomConsole.submit(cmd);
		return;
	
	_applyFromList();


func _applyFromList() -> void:
	var listLen = _listHint.size();
	if !listLen:
		return;
	var indexFinal = _getPositiveIndex();
	_applyHint(_listHint[indexFinal]);


func _resetHintState() -> void:
	_containerHint.visible = false;
	_isHistory = false;
	_isHint = false;
	_index = 0;
	_listHint = [];
	_renderHints();

func _applyHint(text: String) -> void:
	_editCmd.text = text;
	_editCmd.caret_column = text.length();
	_resetHintState();


func _handleEditKeys(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return;
	
	elif event is InputEventKey:
		_handleKey(event);


func _handleInput(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return;
	
	if event is InputEventMouseButton:
		_handleMouseButton(event);
	elif event is InputEventMouseMotion:
		_handleMouseMove(event);


func _handleKey(event: InputEventKey) -> void:
	if event.keycode == KEY_UP || event.keycode == KEY_DOWN || (_isHint && event.keycode == KEY_ESCAPE):
		_editCmd.accept_event();
	
	if !event.is_pressed():
		if (_isHint && event.keycode == KEY_ESCAPE):
			_resetHintState();
		return;
	
	var cmd: String = _editCmd.text;
	if event.keycode == KEY_UP:
		if _containerHint.visible:
			if _isHint:
				_index += 1;
			else:
				_isHint = true;
				_index = 0;
			_renderHints();
			return;
		
		if !cmd:
			if !GsomConsole.history.size():
				return;
			_listHint = GsomConsole.history.duplicate();
			_listHint.reverse();
			_isHistory = true;
			_index = 0;
			_containerHint.visible = true;
			_isHint = true;
			_renderHints();
			return;
		return;
	
	if event.keycode == KEY_DOWN:
		if _containerHint.visible:
			if _isHint:
				_index -= 1;
			else:
				_isHint = true;
				_index = 0;
			_renderHints();
			return;
		
		return;


# Convert `_index` to pozitive and keep within `_listHint` bounds
func _getPositiveIndex() -> int:
	var listLen: int = _listHint.size();
	return ((_index % listLen) + listLen) % listLen;

# Calculate start and end indices of sublist to render
# Returns pair as array: [startIndex, endIndex]
func _getSublist() -> Array[int]:
	var listLen: int = _listHint.size();
	if listLen < 5:
		return [0, listLen];
	
	var indexFinal: int = _getPositiveIndex();
	if indexFinal < 3:
		return [0, 4];
	
	var indexLast = listLen - 1;
	var endAt: int = min(indexFinal + 2, listLen);
	var startAt: int = endAt - 4;
	
	return [startAt, endAt];


func _handleMouseButton(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return;
	
	if event.pressed:
		_isDrag = true;
		_grabPos = event.global_position - self.position;
	else:
		_isDrag = false;


func _handleMouseMove(event: InputEventMouseMotion) -> void:
	if _isDrag:
		self.position = event.global_position - _grabPos;
