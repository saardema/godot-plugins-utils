# @tool
class_name PlotterGrid
extends ColorRect

var _plot_scale := Vector2(1, 1)
var _y_offset: float
var _grid_alpha: float
var _grid_resolution: float
var _font := get_theme_default_font()
var _font_size := 28
var indicator_label_color := Color.BLACK
var text_color := Color.WHITE
var x_label_format: String
var x_label_width: int
var y_label_format: String
var y_label_width: int
var grid_contrast: float

func set_grid(plot_scale: Vector2, offset: float, alpha: float, resolution: float, contrast: float):
	_plot_scale = plot_scale
	_y_offset = offset
	_grid_alpha = alpha
	_grid_resolution = resolution
	text_color.a = clamp(alpha * 4, 0, 1)
	indicator_label_color.a = clamp(alpha * 3 - 0.6, 0, 1)
	grid_contrast = contrast
	queue_redraw()

func _draw_indicator(pos: Vector2, value: float, is_x_axis: bool):
	var text: String
	var width: float

	if is_x_axis:
		if value == 0: return
		text = str(value) + 's'
		width = len(text) * _font_size * 0.7
		pos.x -= width / 2
	else:
		text = str(value)
		width = len(text) * _font_size * 0.7
		pos += Vector2(2, 2)

	draw_rect(Rect2(pos, Vector2(width, _font_size * 1.5)), indicator_label_color)
	pos += Vector2(0, _font_size + 3)
	draw_string(_font, pos, text, 1, width, _font_size, text_color)

class GridAxisConfig:
	var magnitude: float
	var exp: float
	var unit_index: int
	var ticks: int
	var unit: float
	var major_stride: float
	var step: float
	var range: float
	var normalized_range: float
	var count: int
	var t: float

	const log10 := log(10)
	const indices: Array[int] = [0, 1, 1, 1, 2, 2, 3, 3, 3]
	const major_units: Array[float] = [1, 2, 2, 2]
	const grid_units: Array[float] = [2.5, 2.5, 5, 5]
	const minor_units: Array[int] = [5, 5, 5, 5]

	func _init(size: float, scale: float, resolution: float):
		range = scale / resolution / size * 100
		exp = log(range) / log10
		magnitude = 10 ** floor(exp)
		normalized_range = range / magnitude
		unit_index = indices[min(indices.size() - 1, floori(normalized_range - 1))]
		step = grid_units[unit_index] * magnitude / scale * size
		major_stride = major_units[unit_index]
		unit = grid_units[unit_index]
		ticks = minor_units[unit_index]
		count = min(50, size / step + 1)


func _draw() -> void:
	var grid_color := Color(1, 1, 1, _grid_alpha)
	var x_axis := GridAxisConfig.new(size.x, _plot_scale.x, _grid_resolution)
	var y_axis := GridAxisConfig.new(size.y, _plot_scale.y, _grid_resolution)
	var tick_offset := _y_offset / y_axis.unit * y_axis.ticks / y_axis.magnitude
	var y_shift_fract := wrapf(tick_offset, 0, 1)
	var y_shift: int = floor(tick_offset)

	for x in x_axis.count * x_axis.ticks:
		var pos := Vector2(size.x - x * x_axis.step / x_axis.ticks, 0)
		var significance: float = 1

		if x % x_axis.ticks == 0:
			significance = 2
		if x % floori(x_axis.major_stride * x_axis.ticks) == 0:
			significance = 3
			_draw_indicator(pos, x / x_axis.ticks * x_axis.unit * x_axis.magnitude, true)

		significance = pow(significance / 3, grid_contrast)
		grid_color.a = _grid_alpha * significance
		draw_line(pos, Vector2(pos.x, size.y), grid_color, 1 + significance * 3, true)

	for y in y_axis.count * y_axis.ticks:
		var pos := Vector2(0, size.y - (y - y_shift_fract) * y_axis.step / y_axis.ticks)
		var significance: float = 1
		var abs_y: int = y + y_shift

		if abs_y % y_axis.ticks == 0:
			significance = 2
		if fmod(abs_y, y_axis.major_stride * y_axis.ticks) == 0:
			significance = 3
			_draw_indicator(pos, abs_y / y_axis.ticks * y_axis.unit * y_axis.magnitude, false)

		significance = pow(significance / 3, grid_contrast)
		grid_color.a = _grid_alpha * significance
		draw_line(pos, Vector2(size.x, pos.y), grid_color, 1 + significance, true)

	# DebugTools.write('_y_offset', _y_offset, true)
	# DebugTools.write('y_shift', y_shift, true)
	# DebugTools.write('tick_offset', tick_offset, true)
	# DebugTools.write('y_shift_fract', y_shift_fract, true)
	# DebugTools.write('range', y_axis.range, true)
	# DebugTools.write('normalized_range', x_axis.normalized_range, true)
	# DebugTools.write('exp', x_axis.exp, true)
	# DebugTools.write('magnitude', y_axis.magnitude, true)
	# DebugTools.write('unit_index', [x_axis.unit_index, y_axis.unit_index], true)
	# DebugTools.write('unit', y_axis.unit, true)
	# DebugTools.write('count', x_axis.count, true)
	# DebugTools.write('scale', _plot_scale.y, true)
	# DebugTools.write('resolution', resolution, true)
