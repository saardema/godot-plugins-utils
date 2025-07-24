@tool
extends Control
const ToggleLabel = preload("toggle_label.gd")

signal before_toggle(enabled: bool)
signal toggled(enabled: bool, label: ToggleLabel)

@onready var label: Label = %Label
@onready var background: ColorRect = %Background
@onready var color_indicator: ColorRect = %ColorIndicator
var default_background_color: Color

var is_hovered: bool
var use_indicator: bool = true:
	set(v):
		use_indicator = v
		_update_visual_state()

var text: String:
	get: return label.text
	set(v): label.text = v

var indicator_color: Color:
	get: return color_indicator.color
	set(v):
		color_indicator.color = v
		_update_visual_state()


func set_background_color(color: Variant):
	background.color = color if color is Color else default_background_color


func _ready():
	mouse_entered.connect(func(): is_hovered = true; _update_visual_state())
	mouse_exited.connect(func(): is_hovered = false; _update_visual_state())
	default_background_color = background.color
	_update_visual_state()


func _update_visual_state():
	modulate.a = 0.8 if enabled else 0.4
	if is_hovered: modulate.a += 0.2
	color_indicator.color.a = 1 if use_indicator and enabled else 0
	color_indicator.visible = use_indicator


var enabled: bool:
	set(v):
		enabled = v
		_update_visual_state()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not event.pressed and event.button_index == 1 and is_hovered:
			before_toggle.emit(not enabled)
