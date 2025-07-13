class_name Plot
extends Control

var logger: DataLogger
var vectors: PackedVector2Array
var resolution: int
var color: Color
var needle: float
var _last_draw_range: int

func init(point_count := 60, plot_color := Color.WHITE):
	color = plot_color
	resolution = point_count
	vectors.resize(resolution)
	logger = DataLogger.new(resolution * 10, 1.0 / 120, 500)

func set_needle(value: float):
	needle = value

func scroll(time_scale: float, y_scale: float, y_offset: float):
	if resolution == 0:
		push_error('Plot not initialized. Resolution is 0')
		return

	logger.append(needle)

	if not visible: return

	var value: float
	var index: int
	var stride: int = ceili(time_scale)
	var draw_range: int = min(resolution, resolution * time_scale / stride + 2)

	for x in max(draw_range, _last_draw_range):
		index = x * stride
		value = logger.values[(logger.pointer - index) % logger.count_values]

		vectors[x].x = size.x - x * size.x / resolution / time_scale * stride
		vectors[x].y = size.y - size.y * (value - y_offset) / y_scale

	_last_draw_range = draw_range

	DebugTools.write('x', vectors[int(resolution * time_scale / stride) % resolution].x)
	DebugTools.write('r', time_scale / stride)
	DebugTools.write('s', stride)
	DebugTools.write('dr', draw_range)

	queue_redraw()


func _draw():
	draw_polyline(vectors, color, 8, true)
