class_name PlotterGrid
extends ColorRect

var _grid_scale := Vector2(1, 1)
var _y_offset: float
var _grid_alpha: float = 0.1
var _max_grid_unit: float = 100

func set_grid(scale_: Vector2, offset: float, alpha: float, unit: float):
	_grid_scale = scale_
	_y_offset = offset
	_grid_alpha = alpha
	_max_grid_unit = max(5, unit)
	queue_redraw()

func _draw():
	const log2: float = log(2)
	var multiplier_base := size / _max_grid_unit * 2 / _grid_scale / 10
	var multiplier: Vector2
	multiplier.x = floor(max(1, 10 * pow(2, floor(log(multiplier_base.x) / log2))))
	if multiplier.x == 5: multiplier.x = 4
	multiplier.y = 10 * pow(2, floor(log(multiplier_base.y) / log2))
	var spacing: Vector2 = size / _grid_scale / multiplier
	var y_shift := multiplier.y * _y_offset * _grid_scale.y
	var grid_color := Color(1, 1, 1, _grid_alpha)

	for x in range(0, (size.x + 1) / spacing.x + 1, 1):
		var accent: int = 1
		if fmod(x, multiplier.x) == 0.0: accent = 4
		elif multiplier.x > 4 and x % 5 == 0: accent = 2
		grid_color.a = _grid_alpha * accent / 4
		var pos := Vector2(size.x - x * spacing.x + 1, 0)
		draw_line(pos, pos + Vector2(0, size.y), grid_color, accent, true)

	for y in range(0, (size.y + 1) / spacing.y + 1, 1):
		var accent: int = 1
		if y - floor(y_shift) == 0.0: accent = 4
		elif fmod(y - floor(y_shift), multiplier.y) == 0.0: accent = 2
		grid_color.a = _grid_alpha * accent / 4
		var pos := Vector2(0, size.y - y * spacing.y)
		pos.y -= fmod(y_shift, 1) * spacing.y
		draw_line(pos, pos + Vector2(size.x, 0), grid_color, accent, true)
