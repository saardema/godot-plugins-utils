@tool
class_name ToggleLabel
extends Control

signal clicked(label: ToggleLabel)
signal hovered

@onready var label: Label = %Label
@onready var background: ColorRect = %Background
@onready var indicator_right: Control = %IndicatorRight
@onready var indicator_right_rect: ColorRect = %IndicatorRight/ColorRect
@onready var indicator_bottom: Control = %IndicatorBottom
@onready var indicator_bottom_rect: ColorRect = %IndicatorBottom/ColorRect
@onready var highlight: MarginContainer = %Highlight
@onready var icon_container: BoxContainer = %IconContainer
@onready var icon_rect: TextureRect = %IconContainer/TextureRect

enum IndicatorMode {Disabled, WhenToggled, Hide, Show}

var id: StringName
var meta: Variant
var default_background: Color
var default_indicator_color: Color
var is_hovered: bool

var render_indicator: bool:
	get:
		if indicator_mode == IndicatorMode.WhenToggled:
			return is_toggled
		return indicator_mode == IndicatorMode.Show

@export var indicator_mode := IndicatorMode.Hide:
	set(v):
		indicator_mode = v
		_update_visual_state()

@export var use_bottom_indicator: bool:
	set(v):
		use_bottom_indicator = v
		_update_visual_state()

var indicator: ColorRect:
	get:
		if use_bottom_indicator:
			return indicator_bottom
		return indicator_right

@export var text: String:
	set(v):
		text = v
		id = v.to_snake_case()
		if label:
			label.text = v
			label.visible = text != ""

@export var color: Color = Color.TRANSPARENT:
	set(v):
		color = v
		_update_visual_state()

@export var background_color: Color:
	set(v):
		if background: background.color = v
	get: return background.color

@export var icon: Texture2D:
	set(v):
		icon = v
		if icon_rect:
			icon_rect.texture = v
			icon_container.visible = v != null

func toggle_indicator(show: bool, new_color := color):
	indicator_mode = IndicatorMode.Show if show else IndicatorMode.Hide
	if new_color != color: color = new_color


func _ready():
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	default_background = background.color
	default_indicator_color = indicator_right_rect.color
	label.text = text
	label.visible = text != ""
	icon_rect.texture = icon
	icon_rect.get_parent().visible = icon != null
	indicator_right_rect.color = color
	indicator_bottom_rect.color = color
	_update_visual_state()


func _on_hover(state: bool):
	is_hovered = state
	_update_visual_state()
	hovered.emit()


func _update_visual_state():
	if not label: return
	label.label_settings.font_color.a = 1 if is_toggled else 0.3
	#highlight_sb.shadow_color = color.lerp(Color.WHITE, 0.3)
	#highlight_sb.shadow_color.a = 0.07
	highlight.visible = is_hovered
	indicator_bottom_rect.color = color if render_indicator else default_indicator_color
	indicator_right_rect.color = color if render_indicator else default_indicator_color
	indicator_right.visible = not use_bottom_indicator
	indicator_bottom.visible = use_bottom_indicator
	indicator.visible = indicator_mode != IndicatorMode.Disabled

var is_toggled: bool:
	set(v):
		is_toggled = v
		_update_visual_state()


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == 1 and is_hovered:
			clicked.emit(self )
