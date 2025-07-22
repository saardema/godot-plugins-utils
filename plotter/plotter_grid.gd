# @tool
extends Control

var grid_pos := Vector2()
var grid_scale := Vector2(1, 1)
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
var shift_fract: Vector2
var shift: Vector2i
var x_axis: GridAxisConfig
var y_axis: GridAxisConfig
var _x_indicators: Array
var _y_indicators: Array
var plot_mode: Plotter.GridMode
var magnitude: Vector2
var unit: Vector2
var ticks: Vector2

func set_grid(
		plot_pos: Vector2,
		plot_scale: Vector2,
		alpha: float,
		resolution: float,
		contrast: float,
		background_color: Color,
		mode: Plotter.GridMode
	):
	plot_mode = mode
	grid_pos = plot_pos
	grid_scale = plot_scale
	_grid_alpha = alpha
	_grid_resolution = resolution
	indicator_text_color.a = clamp(alpha * 4, 0, 1)
	indicator_label_color = background_color
	indicator_label_color.a = 1
	grid_contrast = contrast
	_update()
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
		text = str(-value)
		if plot_mode == Plotter.GridMode.Time:
			if value == 0: return
			text = str(value) + 's'
		rect.size.x = len(text) * _font_size * 0.7
		rect.position.x -= rect.size.x / 2
		# if rect.position.x < 50:
		# 	fadeout = 1 + (rect.position.x - 50) / rect.size.x * 2
			# rect.position.x = 50

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

func quantize(value: Vector2, to_ticks := false) -> Vector2:
	var factor := magnitude * unit
	if to_ticks: factor /= Vector2(ticks)

	return value.snapped(factor)


func _update():
	var resolution := Vector2.ONE * _grid_resolution / size * size[size.max_axis_index()]
	x_axis = GridAxisConfig.new(size.x, grid_scale.x, resolution.x)
	y_axis = GridAxisConfig.new(size.y, grid_scale.y, resolution.y)
	magnitude = Vector2(x_axis.magnitude, y_axis.magnitude)
	unit = Vector2(x_axis.unit, y_axis.unit)
	ticks = Vector2i(x_axis.ticks, y_axis.ticks)

func _draw() -> void:
	var grid_color := Color(1, 1, 1, _grid_alpha)
	var start: Vector2
	var end: Vector2
	var tick_offset := -grid_pos / unit * ticks / magnitude
	shift_fract = Vector2(wrapf(tick_offset.x, 0, 1), wrapf(tick_offset.y, 0, 1))
	shift = floor(tick_offset)
	var i := -1
	var line_pos: float = 0

	draw_rect(Rect2(Vector2.ZERO, size), indicator_label_color)

	for axis in [x_axis, y_axis]:
		i += 1
		for n in axis.count * axis.ticks:
			line_pos = (n - shift_fract[i]) * axis.step / axis.ticks
			n += shift[i]
			if axis == x_axis:
				start = Vector2i(line_pos, 0)
				end = Vector2(line_pos, size.y)
			else:
				start = Vector2(0, line_pos)
				end = Vector2(size.x, line_pos)
			if line_pos > size[i]: break

			var significance: float = 1
			var value: float = - float(n) / axis.ticks * axis.unit * axis.magnitude

			if value == 0: significance = 5
			elif fmod(n, axis.milestone * axis.ticks) == 0: significance = 3
			elif n % axis.ticks == 0: significance = 2

			if n % floori(axis.major_stride * axis.ticks) == 0:
				_draw_indicator_deferred(start, value, significance, axis == x_axis)

			significance = pow(significance / 5, grid_contrast)
			grid_color.a = _grid_alpha * significance
			draw_line(start, end, grid_color, max(1, significance * 5), true)

	_draw_deferred_indicators()

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

	const milestones: Array[float] = [5, 2, 2, 2, 4]
	const major_units: Array[float] = [1, 1, 1, 1, 1]
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
			if normalized_range < grid_units[i + 1]:
				unit_index = i
				break
		step = grid_units[unit_index] * magnitude / scale * size
		major_stride = major_units[unit_index]
		unit = grid_units[unit_index]
		milestone = milestones[unit_index]
		ticks = minor_units[unit_index]
		count = min(50, size / step + 2)
