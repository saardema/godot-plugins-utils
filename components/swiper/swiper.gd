@tool
extends Control

signal value_changed(value: float)

@onready var name_label: Label = %Label
@onready var value_label: Label = %Value
@onready var slider: HSlider = %Slider

var evaluator := Expression.new()
var _value_range: float:
	get: return range_max - range_min

var _normalized_value: float:
	get: return (_value - range_min) / _value_range

@export var label_text: String:
	set(v):
		label_text = v
		if name_label: name_label.text = v

@export var default_value: float

@export var range_min: float = 0:
	set(v):
		range_min = v
		_update_slider()

@export var range_max: float = 1:
	set(v):
		range_max = v
		_update_slider()

@export var step: float = 0:
	set(v):
		step = v
		_update_slider()

@export var realign_steps: bool:
	set(v):
		realign_steps = v
		_update_slider()

@export var rounded: bool:
	set(v):
		rounded = v
		_update_slider()

@export var exp_edit: bool:
	set(v):
		exp_edit = v
		_update_slider()

@export_exp_easing('positive_only') var val_exp: float = 1:
	set(v):
		val_exp = v
		_update_value_label()

@export var val_exp_base: float = 1:
	set(v):
		val_exp_base = v
		_update_value_label()

@export_range(0, 8) var precision: int = 2:
	set(v):
		precision = v
		_update_value_label()

@export_range(0, 50) var ticks: int:
	set(v):
		ticks = v
		_update_slider()

@export var min_text: String:
	set(v):
		min_text = v
		_update_value_label()

@export var max_text: String:
	set(v):
		max_text = v
		_update_value_label()

@export var suffix: String:
	set(v):
		suffix = v
		_update_value_label()

@export var expression: String:
	set(v):
		expression = v
		_update_value_label()

var value: float:
	set(v):
		if val_exp != 1 or val_exp_base != 1:
			v = _unexponentiate(v)
		_value = clamp(v, range_min, range_max)
		# _update_value_label()
		# DebugTools.write(label_text, _value)
	get:
		if _show_min_text:
			return range_min
		elif _show_max_text:
			return range_max
		elif expression:
			return _get_expression_value()
		elif val_exp != 1 or val_exp_base != 1:
			return _exponentiate(_value)
		return _value

var _value: float

var _show_min_text: bool:
	get:
		if not min_text: return false
		var min_delta := absf(_value - range_min)
		var frag_per_unit := (range_max - range_min) / size.x
		return min_delta < frag_per_unit or min_delta < step

var _show_max_text: bool:
	get:
		if not max_text: return false
		var max_delta := absf(_value - range_max)
		var frag_per_unit := (range_max - range_min) / size.x
		return max_delta < frag_per_unit or max_delta < step

func _ready():
	if default_value != 0:
		set_value_no_signal(default_value)

	name_label.text = label_text
	slider.value_changed.connect(_on_slider_value_changed)
	_update_value_label()
	_update_slider()


func _exponentiate(val: float) -> float:
	if val_exp != 1:
		val = pow(_normalized_value, val_exp) * _value_range + range_min

	if val_exp_base != 0 and val_exp_base != 1:
		val = pow(val_exp_base, val)

	return val


func _unexponentiate(val: float) -> float:
	if val_exp_base != 0 and val_exp_base != 1 and val >= 0:
		val = log(val) / log(val_exp_base)
	if val_exp != 1:
		val = pow((val - range_min) / _value_range, 1 / val_exp) * _value_range + range_min

	return val


func _get_expression_value() -> float:
	var status := evaluator.parse(expression, ['x'])
	if status != OK: return _value

	var result = evaluator.execute([_value])
	if evaluator.has_execute_failed(): return _value

	return result


func _on_slider_value_changed(slider_value: float):
	_value = slider_value
	value_changed.emit(value)
	_update_value_label()


func _update_value_label():
	if not value_label: return

	if _show_min_text:
		value_label.text = min_text
	elif _show_max_text:
		value_label.text = max_text
	else:
		value_label.text = "%0.*f" % [0 if rounded else precision, value]
		if suffix: value_label.text += suffix


func _update_slider():
	if not slider: return

	slider.min_value = range_min
	slider.max_value = range_max
	slider.tick_count = ticks
	slider.step = step
	slider.rounded = rounded
	slider.exp_edit = exp_edit
	_update_value_label()


func set_value_no_signal(new_value: float):
	value = new_value
	if slider: slider.set_value_no_signal(_unexponentiate(value))
	_update_value_label()
