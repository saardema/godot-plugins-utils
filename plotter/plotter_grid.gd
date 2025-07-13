# @tool
class_name PlotterGrid
extends Control

var _plot_scale := Vector2(1, 1)
var _y_offset: float
var _grid_alpha: float
var _grid_resolution: float
var _font := get_theme_default_font()
var _font_size := 28
var indicator_label_color := Color.BLACK
var indicator_text_color := Color.WHITE
var x_label_format: String
var x_label_width: int
var y_label_format: String
var y_label_width: int
var grid_contrast: float
var y_shift_fract: float
var y_shift: int
var x_axis: GridAxisConfig
var y_axis: GridAxisConfig
var _x_indicators: Array
var _y_indicators: Array

func set_grid(
		plot_scale: Vector2,
		offset: float,
		alpha: float,
		resolution: float,
		contrast: float,
		background_color: Color
	):
	_plot_scale = plot_scale
	_y_offset = offset
	_grid_alpha = alpha
	_grid_resolution = resolution
	indicator_text_color.a = clamp(alpha * 4, 0, 1)
	indicator_label_color = background_color
	indicator_label_color.a = 1
	grid_contrast = contrast
	queue_redraw()

func _draw_deferred_indicators():
	for axis in [_x_indicators, _y_indicators]:
		for i in range(0, axis.size(), 3):
			_draw_indicator(axis[i], axis[i + 1], axis[i + 2], axis == _x_indicators)
		axis.clear()

func _draw_indicator_deferred(pos: Vector2, value: float, significance: float, is_x_axis: bool):
	if is_x_axis: _x_indicators.append_array([pos, value, significance])
	else: _y_indicators.append_array([pos, value, significance])

func _draw_indicator(pos: Vector2, value: float, significance: float, is_x_axis: bool):
	var text: String
	var rect := Rect2(pos, Vector2(0, _font_size * 1.5))
	var text_color := indicator_text_color
	var label_color := indicator_label_color
	var fadeout: float = 1

	if is_x_axis:
		if value == 0: return
		text = str(value) + 's'
		rect.size.x = len(text) * _font_size * 0.7
		rect.position.x -= rect.size.x / 2
		# if rect.position.x < 0:
		# 	fadeout = 1 + rect.position.x / rect.size.x * 2
		# 	rect.position.x = 0

	else:
		text = str(value)
		rect.size.x = len(text) * _font_size * 1
		rect.position += Vector2(2, -rect.size.y / 2 + 2)
		# if rect.position.y < 2:
		# 	fadeout = 1 + rect.position.y / rect.size.y * 2
		# 	rect.position.y = 2

	label_color.a *= fadeout
	fadeout *= 0.54 + min(1, significance - 2) * 0.5
	text_color.a *= fadeout
	draw_rect(rect, label_color)
	rect.position += Vector2(0, _font_size + 3)
	draw_string(_font, rect.position, text, 1, rect.size.x, _font_size, text_color)

class GridAxisConfig:
	var magnitude: float
	var exp: float
	var unit_index: int
	var ticks: int
	var unit: float
	var major_stride: float
	var milestone: float
	var step: float
	var range: float
	var normalized_range: float
	var count: int
	var t: float

	const milestones: Array[float] = [5, 2, 4, 2, 4]
	const major_units: Array[float] = [1, 1, 2, 1, 2]
	const grid_units: Array[float] = [1, 2.5, 2.5, 5, 5]
	const minor_units: Array[int] = [5, 4, 5, 5, 5]
	const log10 := log(10)

	func _init(size: float, scale: float, resolution: float):
		range = scale / resolution / size * 100
		exp = log(range) / log10
		magnitude = 10 ** floor(exp)
		normalized_range = range / magnitude
		unit_index = grid_units.size() - 1
		for i in grid_units.size() - 1:
			# if normalized_range < grid_units[i] + (grid_units[i + 1] - grid_units[i]) * 0.5:
			if normalized_range < grid_units[i + 1]:
				unit_index = i
				break
		step = grid_units[unit_index] * magnitude / scale * size
		major_stride = major_units[unit_index]
		unit = grid_units[unit_index]
		milestone = milestones[unit_index]
		ticks = minor_units[unit_index]
		count = min(50, size / step + 2)

func quantize_y(value: float, to_ticks := false):
	var factor: float = y_axis.magnitude * y_axis.unit
	if to_ticks: factor /= y_axis.ticks

	return snappedf(value, factor)


func _draw() -> void:
	var resolution := Vector2.ONE * _grid_resolution / size * size[size.max_axis_index()]
	var grid_color := Color(1, 1, 1, _grid_alpha)
	var abs_y: int
	var start: Vector2
	var end: Vector2
	x_axis = GridAxisConfig.new(size.x, _plot_scale.x, resolution.x)
	y_axis = GridAxisConfig.new(size.y, _plot_scale.y, resolution.y)
	var tick_offset := _y_offset / y_axis.unit * y_axis.ticks / y_axis.magnitude
	y_shift_fract = wrapf(tick_offset, 0, 1)
	y_shift = floori(tick_offset)

	for axis in [x_axis, y_axis]:
		for n in axis.count * axis.ticks:
			if axis == x_axis:
				start = Vector2(size.x - n * axis.step / axis.ticks, 0)
				end = Vector2(start.x, size.y)
				if start.x < -50: break
			else:
				start = Vector2(0, size.y - (n - y_shift_fract) * y_axis.step / y_axis.ticks)
				end = Vector2(size.x, start.y)
				if start.y < -50: break
				n += y_shift

			var significance: float = 1

			if fmod(n, axis.milestone * axis.ticks) == 0: significance = 3
			elif n % axis.ticks == 0: significance = 2

			if n % floori(axis.major_stride * axis.ticks) == 0:
				var value: float = n / axis.ticks * axis.unit * axis.magnitude
				_draw_indicator_deferred(start, value, significance, axis == x_axis)

			significance = pow(significance / 3, grid_contrast)
			grid_color.a = _grid_alpha * significance
			draw_line(start, end, grid_color, max(1, significance * 3), true)

	_draw_deferred_indicators()

	# DebugTools.write('normalized_range', Vector2(x_axis.normalized_range, y_axis.normalized_range), false)
	# DebugTools.write('magnitude', Vector2(x_axis.magnitude, y_axis.magnitude), true)
	# DebugTools.write('unit', y_axis.unit, true)
	# DebugTools.write('unit_index', [x_axis.unit_index, y_axis.unit_index], true)
	# DebugTools.write('_y_offset', _y_offset, true)
	# DebugTools.write('y_shift', y_shift, true)
	# DebugTools.write('tick_offset', tick_offset, true)
	# DebugTools.write('y_shift_fract', y_shift_fract, true)
	# DebugTools.write('range', y_axis.range, true)
	# DebugTools.write('exp', x_axis.exp, true)
	# DebugTools.write('count', x_axis.count, true)
	# DebugTools.write('scale', _plot_scale.y, true)
	# DebugTools.write('resolution', resolution, true)
