# @tool
class_name Plotter
extends ColorRect
const PLOT = preload("uid://yci8yyd3rpls")

@onready var grid: PlotterGrid = $Grid
const MIN_Y_SCALE: float = pow(10, -3)
const MAX_Y_SCALE: float = pow(10, 3)
const MIN_TIME_SCALE: float = 0.1
const MAX_TIME_SCALE: float = 10
const MAX_OFFSET: float = 1000
const MAX_PLOTS: int = 10

var plots: Array[Plot]
var resolution: int = 120
var data_logger := DataLogger.new(resolution)
var _current_plot: float
var _update_interval: float = 1.0 / resolution
var _update_timer: float = 0
var _initial_mouse_event_data: Array
var average_plot: Plot

@export_group('Plot')
@export var show_plot: bool = true
@export var show_avg: bool = false
@export var colors: Array[Color] = [Color.WEB_GREEN, Color.ORANGE]
@export_range(-1, 1) var test_plot: float = 0.5

@export_range(0, 1) var avg_range: float = 0.5:
	set(v):
		avg_range = v
		if plots.size():
			plots[0].logger.average_range = plots[0].resolution * v

@export_group('Scale')
@export_range(MIN_TIME_SCALE, MAX_TIME_SCALE, 0.01, "suffix:s") var time_scale: float = 1:
	set(v):
		time_scale = clampf(v, MIN_TIME_SCALE, MAX_TIME_SCALE)
		_update_timing()

@export_range(-2, 2) var zoom: float = 0:
	set(v):
		zoom = v
		y_scale = pow(10, -v)

var y_scale: float = 1:
	set(v):
		y_scale = clampf(v, MIN_Y_SCALE, MAX_Y_SCALE)
		_update_grid()

@export var y_offset: float:
	set(v):
		y_offset = clamp(v, -MAX_OFFSET, MAX_OFFSET)
		_update_grid()

@export_group("Grid")
@export_range(0, 1) var grid_alpha: float = 0.3:
	set(v):
		grid_alpha = v
		_update_grid()

@export_exp_easing() var grid_resolution: float = 0.25:
	set(v):
		grid_resolution = v
		_update_grid()

@export_exp_easing() var grid_contrast: float = 1.5:
	set(v):
		grid_contrast = v
		_update_grid()

@export var background_color: Color = color:
	set(v):
		v.a = 1
		color = v
		_update_grid()

@export_range(0, 2) var scroll_sensitivity: float = 1


func _update_grid():
	if grid: grid.set_grid(
		Vector2(time_scale, y_scale),
		y_offset,
		grid_alpha,
		grid_resolution,
		grid_contrast,
		color)


func _update_timing():
	_update_interval = time_scale / resolution
	_update_timer = min(_update_timer, _update_interval)
	data_logger.refresh_rate = _update_interval
	_update_grid()


func _add_plot():
	var plot := PLOT.instantiate()
	plot.init(resolution, colors[plots.size() % colors.size()])
	plots.append(plot)
	add_child(plot)


func _ready():
	average_plot = PLOT.instantiate()
	average_plot.init(resolution, Color.CYAN)
	average_plot.logger.average_range = avg_range
	add_child(average_plot)

func _process(delta: float):
	var t: float = Time.get_ticks_msec() / 1000.0
	var sine := remap(sin(t * PI * 1.1), -1, 1, 0, 1)
	var square := -1 if (Time.get_ticks_msec() % 2000) < 1000 else 1
	plots[0].visible = show_plot
	var r = plots[0].logger.get_relative(5)
	var a = average_plot.needle
	var ar = average_plot.logger.get_relative(5)
	var v = ar * 0.9 + randf() * 0.1
	plots[0].set_needle(sine)

	for p in plots.size(): plots[p].scroll(time_scale, y_scale, y_offset)

	average_plot.visible = show_avg
	if show_avg:
		average_plot.set_needle(plots[0].logger.average)
		average_plot.scroll(time_scale, y_scale, y_offset)


func plot(y: float, plot_index := 0):
	if plot_index >= plots.size():
		plot_index = min(MAX_PLOTS, plot_index)
		while plot_index >= colors.size(): colors.append(Color(randf(), randf(), randf()))
		while plot_index >= plots.size(): _add_plot()

	plots[plot_index].set_needle(y)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var snapped_plot_pos := screen_to_plot(event.position, true)
		var screen_proportion := 1 - (plot_to_screen(snapped_plot_pos) / size.y).y

		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_initial_mouse_event_data = [
				event.position,
				Vector2(),
				y_offset,
				y_scale,
				time_scale,
				screen_proportion
			]

		elif event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			var direction: float = -1
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: direction = 1

			var factor := pow(10, scroll_sensitivity) * 0.0015 * direction
			var new_scale: float = pow(10, log(y_scale) / log(10) + factor)
			y_offset += (y_scale - new_scale) * screen_proportion
			y_scale = new_scale

	if event is InputEventMouseMotion:
		var data := _initial_mouse_event_data
		if not data.size(): return

		if event.button_mask & (MOUSE_BUTTON_LEFT | MOUSE_BUTTON_RIGHT):
			data[1] = event.position - data[0]
		else: return

		if event.button_mask == MOUSE_BUTTON_MASK_LEFT:
			y_offset = data[2] + data[1].y * data[3] / size.y
			time_scale = data[4] + data[4] * data[1].x / max(100, size.x - event.position.x)

		elif event.button_mask == MOUSE_BUTTON_MASK_RIGHT:
			if is_equal_approx(y_scale, MIN_Y_SCALE) and event.relative.x > 0:
				return

			if is_equal_approx(y_scale, MAX_Y_SCALE) and event.relative.x < 0:
				return

			y_scale = pow(10, log(data[3]) / log(10) + data[1].x * -0.001)
			y_offset = data[2] + (data[3] - y_scale) * data[5]


func screen_to_plot(pos: Vector2, quantize := false, to_ticks := true) -> Vector2:
	pos /= size
	pos.x = (1 - pos.x) * time_scale
	pos.y = (1 - pos.y) * y_scale + y_offset

	if quantize: pos.y = grid.quantize_y(pos.y, to_ticks)

	return pos


func plot_to_screen(pos: Vector2) -> Vector2:
	pos.x = 1 - pos.x / time_scale
	pos.y = 1 - (pos.y - y_offset) / y_scale
	pos *= size

	return pos
