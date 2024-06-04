@tool
extends Control

## The default UI for GsomConsole.
class_name GsomConsolePanel

# This wrapper is used to bypass the `add_custom_type` limitation that only allows adding scripts.
# The script immediatelly instantiates `_sceneConsole`, even in Editor - what you see is what you get.

const MIN_WIDTH: float = 480;
const MIN_HEIGHT: float = 320;

const _sceneConsole: PackedScene = preload("../nodes/console.tscn")
var _inst: Control = null;


var _blur: float = 0.5;
## Background blur intensity. Blur is only visible while `color.a` is below 1.
@export_range(0.0, 1.0) var blur: float = 0.6:
	get:
		return _blur;
	set(v):
		_blur = v;
		_assignBlur();


var _color: Color = Color(0.0, 0.0, 0.0, 0.3);
## Panel background color. When alpha is 0 - only blur applied, if 1 no blur visible.
@export var color: Color = Color(0.0, 0.0, 0.0, 0.3):
	get:
		return _color;
	set(v):
		_color = v;
		_assignColor();


var _labelWindow: String = "Console";
## The window title displayed at the top left corner.
@export var labelWindow: String = "Console":
	get:
		return _labelWindow;
	set(v):
		if _labelWindow == v:
			return;
		_labelWindow = v;
		_assignLabelWindow();


var _labelSubmit: String = "submit";
## The label on "submit" button at the bottom right. 
@export var labelSubmit: String = "submit":
	get:
		return _labelSubmit;
	set(v):
		if _labelSubmit == v:
			return;
		_labelSubmit = v;
		_assignLabelSubmit();


var _isResizeEnabled: bool = true;
## Makes window borders draggable. 
@export var isResizeEnabled: bool = true:
	get:
		return _isResizeEnabled;
	set(v):
		if _isResizeEnabled == v:
			return;
		_isResizeEnabled = v;
		_assignIsResizeEnabled();


var _isDraggable: bool = true;
## Makes window borders draggable. 
@export var isDraggable: bool = true:
	get:
		return _isDraggable;
	set(v):
		if _isDraggable == v:
			return;
		_isDraggable = v;
		_assignIsDraggable();


func _assignLabelWindow() -> void:
	if _inst:
		_inst.get_node("Panel/ColumnMain/RowTitle/LabelTitle").text = _labelWindow;


func _assignLabelSubmit() -> void:
	if _inst:
		_inst.get_node("Panel/ColumnMain/RowInput/ButtonSubmit").text = _labelSubmit;


func _assignBlur() -> void:
	if !_inst:
		return;
	
	_inst.get_node("Panel/Blur").material.set_shader_parameter("blur", _blur * 5.0);


func _assignColor() -> void:
	if !_inst:
		return;
	
	_inst.get_node("Panel/Blur").material.set_shader_parameter("color", _color);


func _assignIsResizeEnabled() -> void:
	if !_inst:
		return;
	
	_inst.get_node("Resizers").visible = _isResizeEnabled;


func _assignIsDraggable() -> void:
	if !_inst:
		return;
	
	_inst.get_node("Draggable").visible = _isDraggable;


func _ready() -> void:
	self.custom_minimum_size = Vector2(MIN_WIDTH, MIN_HEIGHT);
	_inst = _sceneConsole.instantiate();
	add_child(_inst);
	
	var blurPanel: Control = _inst.get_node("Panel/Blur");
	blurPanel.material = blurPanel.material.duplicate(true);
	
	_assignBlur();
	_assignColor();
	_assignLabelWindow();
	_assignLabelSubmit();
	_assignIsResizeEnabled();
	_assignIsDraggable();
