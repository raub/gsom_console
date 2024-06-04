extends Control

const MIN_WIDTH: float = 480;
const MIN_HEIGHT: float = 320;

@onready var _draggable: Control = $Draggable;
@onready var _blur: Control = $Panel/Blur;
@onready var _labelLog: RichTextLabel = $Panel/ColumnMain/BgLog/LabelLog;
@onready var _buttonClose: Button = $Panel/ColumnMain/RowTitle/ButtonClose;
@onready var _buttonSubmit: Button = $Panel/ColumnMain/RowInput/ButtonSubmit;
@onready var _editCmd: LineEdit = $Panel/ColumnMain/RowInput/ContainerCmd/EditCmd;
@onready var _containerHint: Control = $Panel/ColumnMain/BgLog/ContainerHint;
@onready var _columnHint: Control = $Panel/ColumnMain/BgLog/ContainerHint/ContainerHintInner/ColumnHint;
@onready var _resizeTop: Control = $Resizers/ResizeTop;
@onready var _resizeBottom: Control = $Resizers/ResizeBottom;
@onready var _resizeLeft: Control = $Resizers/ResizeLeft;
@onready var _resizeRight: Control = $Resizers/ResizeRight;


var _isDrag: bool = false;
var _isResize: bool = false;
var _grabPosMouse := Vector2();
var _grabPosWrapper := Vector2();
var _grabSize := Vector2();
var _isHint: bool = false;
var _listHint: Array[String] = [];
var _isHistory: bool = false;
var _index: int = 0;


var _wrapperPos: Vector2 = Vector2.ZERO:
	get:
		return get_parent().position;
	set(v):
		get_parent().position = v;


var _wrapperSize: Vector2 = Vector2(MIN_WIDTH, MIN_HEIGHT):
	get:
		return get_parent().size;
	set(v):
		get_parent().size = v;

var _wrapperWigth: float = MIN_WIDTH:
	get:
		return _wrapperSize.x;
	set(v):
		_wrapperSize.x = v;

var _wrapperHeight: float = MIN_HEIGHT:
	get:
		return _wrapperSize.y;
	set(v):
		_wrapperSize.y = v;


var _viewSize: Vector2 = Vector2(MIN_WIDTH, MIN_HEIGHT):
	get:
		return get_viewport().size;


var _viewWigth: float = MIN_WIDTH:
	get:
		return _viewSize.x;

var _viewHeight: float = MIN_HEIGHT:
	get:
		return _viewSize.y;


func _ready() -> void:
	_draggable.gui_input.connect(_handleInputDrag);
	_editCmd.gui_input.connect(_handleEditKeys);
	_resizeTop.gui_input.connect(_handleInputResizeTop);
	_resizeBottom.gui_input.connect(_handleInputResizeBottom);
	_resizeLeft.gui_input.connect(_handleInputResizeLeft);
	_resizeRight.gui_input.connect(_handleInputResizeRight);
	
	GsomConsole.onToggle.connect(_handleVisibility);
	_handleVisibility(GsomConsole.isVisible);
	
	GsomConsole.onLog.connect(_handleLogChange);
	_handleLogChange();
	
	_buttonClose.pressed.connect(GsomConsole.hide);
	_buttonSubmit.pressed.connect(_handleSubmit);
	_editCmd.text_submitted.connect(_handleSubmit);
	
	_editCmd.text_changed.connect(_handleTextChange);
	_handleTextChange(_editCmd.text);
	
	for child: Button in _columnHint.get_children():
		child.pressed.connect(_handleHintButton.bind(child));


#region Console Input Handlers

func _handleVisibility(isVisible: bool) -> void:
	visible = isVisible;
	if isVisible:
		_editCmd.grab_focus();
	else:
		_editCmd.text = "";
		_resetHintState();


func _handleLogChange(_text: String = "") -> void:
	_labelLog.text = GsomConsole.logText;


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
	
	var matchList: Array[String] = GsomConsole.getMatches(text);
	if !matchList.size():
		return;
	
	_listHint = matchList.duplicate();
	_containerHint.visible = true;
	_renderHints();


func _handleSubmit(_text: String = "") -> void:
	var cmd: String = _editCmd.text;
	
	if !_isHint:
		_resetHintState();
		
		if !cmd:
			return;
		
		_editCmd.text = "";
		GsomConsole.submit(cmd);
		return;
	
	_applyFromList();


func _handleEditKeys(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return;
	
	elif event is InputEventKey:
		_handleKey(event);


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

#endregion

#region Hints View

func _applyFromList() -> void:
	var listLen: int = _listHint.size();
	if !listLen:
		return;
	var indexFinal: int = _getPositiveIndex();
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


func _renderHints() -> void:
	if !_containerHint.visible:
		return;
		
	var subRange: Array[int] = _getSublist();
	var sublist: Array[String] = _listHint.slice(subRange[0], subRange[1]) as Array[String];
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
	
	var indexLast: int = listLen - 1;
	var endAt: int = min(indexFinal + 2, listLen);
	var startAt: int = endAt - 4;
	
	return [startAt, endAt];

#endregion

#region Drag Handlers

func _handleInputDrag(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return;
	
	if event is InputEventMouseButton:
		_handleMouseButtonDrag(event);
	elif event is InputEventMouseMotion:
		_handleMouseMoveDrag(event);


func _handleMouseButtonDrag(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return;
	
	if event.pressed:
		_isDrag = true;
		_grabPosMouse = event.global_position - _wrapperPos;
	else:
		_isDrag = false;


func _handleMouseMoveDrag(event: InputEventMouseMotion) -> void:
	if !_isDrag:
		return;
		
	_wrapperPos = event.global_position - _grabPosMouse;

#endregion

#region Resize Handlers

func _handleMouseButtonResize(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return;
	
	if event.pressed:
		_isResize = true;
		_grabSize = _wrapperSize;
		_grabPosWrapper = _wrapperPos;
		_grabPosMouse = event.global_position;
	else:
		_isResize = false;


func _handleInputResizeTop(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return;
	
	if event is InputEventMouseButton:
		_handleMouseButtonResize(event);
	elif event is InputEventMouseMotion and _isResize:
		_handleMouseMoveResizeTop(event);


func _handleInputResizeBottom(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return;
	
	if event is InputEventMouseButton:
		_handleMouseButtonResize(event);
	elif event is InputEventMouseMotion and _isResize:
		_handleMouseMoveResizeBottom(event);


func _handleInputResizeLeft(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return;
	
	if event is InputEventMouseButton:
		_handleMouseButtonResize(event);
	elif event is InputEventMouseMotion and _isResize:
		_handleMouseMoveResizeLeft(event);


func _handleInputResizeRight(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return;
	
	if event is InputEventMouseButton:
		_handleMouseButtonResize(event);
	elif event is InputEventMouseMotion and _isResize:
		_handleMouseMoveResizeRight(event);


func _handleMouseMoveResizeTop(event: InputEventMouseMotion) -> void:
	var dy: float = event.global_position.y - _grabPosMouse.y;
	var newY: float = clamp(_grabPosWrapper.y + dy, 0.0, _viewHeight);
	var newH: float = _grabSize.y + (_grabPosMouse.y - newY);
	if newH < MIN_HEIGHT:
		return;
	
	_wrapperPos.y = newY;
	_wrapperHeight = newH;


func _handleMouseMoveResizeBottom(event: InputEventMouseMotion) -> void:
	var dy: float = event.global_position.y - _grabPosMouse.y;
	var newH: float = _grabSize.y + dy;
	if newH < MIN_HEIGHT || (newH + _grabPosWrapper.y > _viewHeight):
		return;
	
	_wrapperHeight = newH;


func _handleMouseMoveResizeLeft(event: InputEventMouseMotion) -> void:
	var dx: float = event.global_position.x - _grabPosMouse.x;
	var newX: float = clamp(_grabPosWrapper.x + dx, 0.0, _viewWigth);
	var newW: float = _grabSize.x + (_grabPosMouse.x - newX);
	if newW < MIN_WIDTH:
		return;
	
	_wrapperPos.x = newX;
	_wrapperWigth = newW;


func _handleMouseMoveResizeRight(event: InputEventMouseMotion) -> void:
	var dx: float = event.global_position.x - _grabPosMouse.x;
	var newW: float = _grabSize.x + dx;
	if newW < MIN_WIDTH || (newW + _grabPosWrapper.x > _viewWigth):
		return;
	
	_wrapperWigth = newW;

#endregion
