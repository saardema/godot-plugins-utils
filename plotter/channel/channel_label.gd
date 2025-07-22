extends Control

signal channel_toggled(enabled: bool)

@onready var label: Label = %Label
@onready var color_rect: ColorRect = %ColorRect


func _init():
	modulate.a = 0.8 if enabled else 0.5
	mouse_entered.connect(_on_state_change.bind(true))
	mouse_exited.connect(_on_state_change.bind(false))


func _on_state_change(is_hovered: bool):
	modulate.a = 0.8 if enabled else 0.5
	if is_hovered: modulate.a += 0.2


var enabled: bool = true:
	set(v):
		enabled = v
		_on_state_change(false)
		color_rect.visible = v
		channel_toggled.emit(enabled)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == 1:
			enabled = not enabled
