# @tool
class_name Plotter
extends Panel

@onready var grid: PlotterGrid = $Grid
const MIN_Y_SCALE: float = pow(10, -2)
const MAX_Y_SCALE: float = 100
const MIN_TIME_SCALE: float = 0.1
const MAX_TIME_SCALE: float = 10

var _plot_vectors: Array[PackedVector2Array]
var _vectors: PackedVector2Array
var resolution: int = 120
var data_logger := DataLogger.new(resolution)
var _current_plot: float
var _update_interval: float = 1.0 / resolution
var _update_timer: float = 0

@export_group('Plot')
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

@export_group('Scale')
@export_range(MIN_TIME_SCALE, MAX_TIME_SCALE, 0.01, "suffix:s") var time_scale: float = 1:
	set(v):
		time_scale = max(0.1, v)
		update_timing()

@export_range(-2, 2) var zoom: float = 0:
	set(v):
		zoom = v
		y_scale = pow(10, -v)

var y_scale: float = 1:
	set(v):
		y_scale = clampf(v, MIN_Y_SCALE, MAX_Y_SCALE)
		update_grid()

@export var y_offset: float:
	set(v):
		y_offset = clamp(v, -100, 100)
		update_grid()

@export_group("Grid")
@export_range(0, 1) var grid_alpha: float = 0.2:
	set(v):
		grid_alpha = v
		update_grid()

@export_exp_easing() var grid_resolution: float = 1:
	set(v):
		grid_resolution = v
		update_grid()

@export_exp_easing() var grid_contrast: float = 1.5:
	set(v):
		grid_contrast = v
		update_grid()

func _on_resize():
	update_grid()
	init_vectors()

func update_grid():
	if grid: grid.set_grid(
		Vector2(time_scale, y_scale),
		y_offset,
		grid_alpha,
		grid_resolution,
		grid_contrast)

func update_timing():
	_update_interval = time_scale / resolution
	_update_timer = min(_update_timer, _update_interval)
	data_logger.refresh_rate = _update_interval
	update_grid()


func init_vectors():
	for i in _plot_vectors.size():
		_plot_vectors[i].resize(resolution)
		for x in resolution:
			_plot_vectors[i][x].x = size.x - (x) * size.x / (resolution)

func _ready():
	_plot_vectors.resize(2)
	resized.connect(_on_resize)
	_on_resize()
	update_timing()

func _process(delta: float):
	_update_timer += delta

	if _update_timer > _update_interval:
		_update_timer = min(_update_timer - _update_interval, _update_interval)
		_update_plot()

func _update_plot():
	var t: float = Time.get_ticks_msec() / 1000.0
	# _current_plot = -1 if (Time.get_ticks_msec() % 2000) < 1000 else 1
	_current_plot = remap(sin(t * PI * 1), -1, 1, 0, 1)
	# _current_plot = test_plot
	data_logger.append(_current_plot)

	if show_plot:
		var value: float
		for x in resolution:
			if time_scale < 1:
				value = data_logger.interpolate((data_logger.pointer - 1) - x * time_scale)
			else:
				value = data_logger.get_relative(x + 1)
			value = (value - y_offset) / y_scale
			_plot_vectors[0][x].y = size.y - size.y * value

	if show_avg:
		for x in resolution - 1:
			_plot_vectors[1][-x - 1].y = _plot_vectors[1][-x - 2].y

		var value: float = data_logger.average / y_scale - y_offset
		_plot_vectors[1][0].y = size.y - size.y * value

	queue_redraw()

var _mouse_event_in_progress: bool
var _initial_mouse_event_pos: Vector2

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask > 0 and not _mouse_event_in_progress:
			_initial_mouse_event_pos = event.position

		_mouse_event_in_progress = event.button_mask > 0

		if event.button_mask & MOUSE_BUTTON_LEFT > 0:
			y_offset += event.relative.y * y_scale / size.y
			var displacement: float = time_scale * event.relative.x / max(100, size.x - event.position.x)
			time_scale = clampf(time_scale + displacement, MIN_TIME_SCALE, MAX_TIME_SCALE)
		elif event.button_mask & MOUSE_BUTTON_RIGHT > 0:
			var increment: float = y_scale * event.relative.x * -0.003
			y_scale += increment
			y_offset -= increment * (1 - _initial_mouse_event_pos.y / size.y)

func plot(y: float):
	_current_plot = y

func _draw():
	if show_plot:
		draw_polyline(_plot_vectors[0], color_1, 2, true)

	if show_avg:
		draw_polyline(_plot_vectors[1], color_2, 1, true)
