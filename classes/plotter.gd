# @tool
class_name Plotter
extends Panel

@onready var grid: PlotterGrid = $Grid

var _plot_vectors: Array[PackedVector2Array]
var _vectors: PackedVector2Array
var resolution: int = 120
var data_logger := DataLogger.new(resolution)
var _current_plot: float
var _update_interval: float = 1.0 / resolution
var _update_timer: float = 0

@export var show_plot: bool = true
@export var show_avg: bool = true
@export var color_1: Color = Color.WEB_GREEN
@export var color_2: Color = Color.ORANGE
@export_range(-1, 1) var test_plot: float = 0.5

@export_range(0, 1) var avg_range: float = 0.5:
	set(v):
		avg_range = v
		if data_logger:
			data_logger.average_range = max(1, v * data_logger.count_values)
			if v == 1: data_logger.average_range = -1

@export_range(0.1, 10, 0.01, "suffix:s") var time_scale: float = 1:
	set(v):
		v = max(0.1, v)
		update_timing(v, time_scale)
		time_scale = v

@export_range(0.1, 10) var y_scale: float = 1:
	set(v):
		y_scale = v
		update_grid()

@export var y_offset: float:
	set(v):
		y_offset = v
		update_grid()

@export_group("Grid")
@export_range(0, 1) var grid_alpha: float = 0.1
@export var grid_unit: int = 100

func _on_resize():
	update_grid()
	init_vectors()

func update_grid():
	if grid: grid.set_grid(Vector2(time_scale, y_scale), y_offset, grid_alpha, grid_unit)

func update_timing(value: float, old_value: float):
	update_grid()
	# data_logger.reset()
	_update_interval = time_scale / resolution
	_update_timer = min(_update_timer, _update_interval)
	data_logger.refresh_rate = _update_interval
	init_vectors()

func init_vectors():
	var spacing: float = size.x / (resolution - 1) / minf(1, time_scale)
	for i in _plot_vectors.size():
		_plot_vectors[i].resize(resolution)
		for x in resolution:
			_plot_vectors[i][x].x = (resolution - 1 - x) * spacing

func _ready():
	_plot_vectors.resize(2)
	resized.connect(_on_resize)
	_on_resize()
	update_timing(time_scale, 0)

func _process(delta: float):
	_update_timer += delta

	if _update_timer > _update_interval:
		_update_timer = min(_update_timer - _update_interval, _update_interval)
		_update_plot()

func _update_plot():
	var t: float = Time.get_ticks_msec() / 1000.0
	# _current_plot = -1 if (Time.get_ticks_msec() % 2000) < 1000 else 1
	_current_plot = remap(sin(t * PI * 0.8), -1, 1, -1, 1)
	data_logger.append(_current_plot)

	if show_plot:
		var value: float
		for x in resolution:
			value = data_logger.values[data_logger._pointer - x - 1]
			value = value / y_scale + y_offset
			_plot_vectors[0][x].y = size.y - size.y * value

	if show_avg:
		for x in resolution - 1:
			_plot_vectors[1][-x - 1].y = _plot_vectors[1][-x - 2].y

		var value: float = data_logger.average / y_scale + y_offset
		_plot_vectors[1][0].y = size.y - size.y * value

	queue_redraw()

func plot(y: float):
	_current_plot = y

func _draw():
	if show_plot:
		draw_polyline(_plot_vectors[0], color_1, 2, true)

	if show_avg:
		draw_polyline(_plot_vectors[1], color_2, 1, true)
