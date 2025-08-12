# @tool
class_name Plotter
extends Control

#region Head

signal draw_mode_changed
signal transform_changed

const Plot = preload("plot/plot.gd")
const TimeGraph = preload("time_graph.gd")
const DotPlot = preload("plot/dotplot/dot_plot.gd")
const Channel = preload('channel/channel.gd')
const Connection = preload('connection/connection.gd')
const State = preload('state/state.gd')

@onready var dot_plot: DotPlot = $DotPlot
@onready var grid: Control = $Grid
@onready var plotter_gui: MarginContainer = $PlotterGUI
@onready var line_plot: Control = %LinePlot
@onready var time_graph_container: Control = %TimeGraphs
var time_graphs: Dictionary[StringName, TimeGraph]

const MIN_Y_SCALE: float = pow(10, -3)
const MAX_Y_SCALE: float = pow(10, 3)
const MIN_TIME_SCALE: float = 0.1
const MAX_TIME_SCALE: float = 10
const MIN_X_SCALE := MIN_Y_SCALE
const MAX_X_SCALE := MAX_Y_SCALE
const MAX_OFFSET: float = 1000
const MAX_CHANNELS: int = 10


#endregion Head


#region Visual

enum DrawMode {Time, Lines, Dots, Oscilloscope}
enum GridMode {Time, XY}
enum Feature {X, Y, Color, Size, Width, Alpha}

const draw_mode_features: Dictionary[DrawMode, Array] = {
	DrawMode.Time: [
		Feature.Y
	],
	DrawMode.Lines: [
		Feature.X,
		Feature.Y,
		Feature.Size,
		Feature.Color,
		Feature.Alpha
	],
	DrawMode.Dots: [
		Feature.X,
		Feature.Y,
		Feature.Size,
		Feature.Color,
		Feature.Alpha
	],
	DrawMode.Oscilloscope: [
		Feature.X,
		Feature.Y
	]

}

@export_group('Plot')
@export var draw_mode: DrawMode:
	set(v):
		if draw_mode != v:
			draw_mode = v
			_on_draw_mode_changed()
		draw_mode = v

@export var colors: Array[Color]

@export_group("Dots")
@export var dot_size: float:
	get: return dot_plot.base_size if dot_plot else 1
	set(v): if dot_plot: dot_plot.base_size = v
@export var dot_color_mode: Plot.ColorMode:
	get: return dot_plot.color_mode if dot_plot else 0
	set(v): if dot_plot: dot_plot.color_mode = v

@export_group("Lines")
@export var line_width: float:
	get: return line_plot.line_width if line_plot else 10
	set(v): if line_plot: line_plot.line_width = v
@export var line_color_mode: Plot.ColorMode:
	get: return line_plot.color_mode if line_plot else 0
	set(v): if line_plot: line_plot.color_mode = v

#endregion Visual

#region Grid

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

@export var background_color := Color(0.07, 0.07, 0.07):
	set(v):
		v.a = 1
		background_color = v
		_update_grid()

@export_range(0, 2) var scroll_sensitivity: float = 1

#endregion Grid


#region Connections

var state: State


#endregion Connections


#region Channels

signal channel_added(channel: Channel)
signal channel_removed(channel_name: StringName)
signal channels_changed

var channels: Dictionary[StringName, Channel] = {}
var last_packet_hash: int

func create_channel(channel_name: String, sub_channels := 1) -> Channel:
	var channel: Channel = Channel.new(channel_name, sub_channels, 256, false)

	add_channel(channel)

	return channel


func add_channel(channel: Channel):
	if channel.name in channels:
		push_warning("Channel already exists: " + channel.name)
		return

	channels[channel.name] = channel
	# printt('Add channel:', channel.name, channel.color)
	if not channel.color: channel.color = colors.pop_front()

	channel.sub_channel_added.connect(func(_c): channels_changed.emit())
	channel.sub_channel_removed.connect(func(_c): channels_changed.emit())
	channel_added.emit(channel)
	channels_changed.emit()


func remove_channel(channel: Channel):
	if channel.name in channels:
		var index := channels.find
		channels.erase(channel.name)
		channel_removed.emit(channel.name)

#endregion Channels


#region Transform

var plot_pos := Vector2(0.1, 1.1):
	set(v):
		plot_pos = v
		transform_changed.emit()
		_update_grid()

var plot_scale := Vector2(1.2, 1.2):
	set(v):
		plot_scale.y = clampf(v.y, MIN_Y_SCALE, MAX_Y_SCALE)
		if draw_mode == DrawMode.Time:
			plot_scale.x = clamp(v.x, MIN_TIME_SCALE, MAX_TIME_SCALE)
		else:
			plot_scale.x = clamp(v.x, MIN_X_SCALE, MAX_X_SCALE)

		transform_changed.emit()
		_update_grid()

func _update_grid():
	if grid: grid.set_grid(
		plot_pos,
		plot_scale,
		grid_alpha,
		grid_resolution,
		grid_contrast,
		background_color,
		draw_mode)

func _on_draw_mode_changed():
	if draw_mode == DrawMode.Time:
		plot_pos = plot_scale

	if time_graph_container: time_graph_container.visible = draw_mode == DrawMode.Time
	if dot_plot: dot_plot.visible = draw_mode == DrawMode.Dots
	if line_plot: line_plot.visible = draw_mode == DrawMode.Lines

	_update_grid()
	draw_mode_changed.emit()

func fit_scale_to_size(min_scale: float):
	if not size: return

	var aspect := size.y / size.x
	if aspect < 1:
		plot_scale = Vector2(min_scale, min_scale * aspect)
	else:
		plot_scale = Vector2(min_scale / aspect, min_scale)


func clear():
	dot_plot.clear()

func _on_resize():
	_update_grid()

#endregion Transform


#region Virtuals

func _ready():
	state = State.new(self )

	_on_draw_mode_changed()
	resized.connect(_on_resize)

	dot_plot.init(Color.WHITE)

	var hue := randf()
	for i in MAX_CHANNELS - colors.size():
		hue = wrapf(hue + 0.2, 0, 1)
		var color := Color.from_hsv(hue, 1, .7)
		colors.append(color)

	plotter_gui.init()


func _physics_process(delta: float):
	if zoom_enabled: auto_zoom()
	var inactive_graphs: Array[TimeGraph] = time_graphs.values()

	if draw_mode == DrawMode.Time:
		for connection in state.find({'feature': Feature.Y}, true):
			var graph: TimeGraph = get_or_add_time_graph(connection['channel_name'], connection['sub_channel'])
			graph.set_needle(connection['channel'].read_single(connection['sub_channel']))
			graph.scroll(delta, plot_scale, plot_pos.y)
			graph.visible = true
			inactive_graphs.erase(graph)

		for graph in inactive_graphs: graph.visible = false


func _process(delta: float):
	if draw_mode == DrawMode.Lines or draw_mode == DrawMode.Dots:
		var target_plot: Plot = [line_plot, dot_plot][draw_mode - 1]
		var feature_list = draw_mode_features[draw_mode]
		var packet_size := 0
		var packet: Dictionary[Feature, PackedFloat32Array]
		var connections = state.find({'feature': feature_list}, true)

		for connection in connections:
			if connection['feature'] in feature_list:
				packet[connection['feature']] = connection['channel'].get_buffer(connection['sub_channel'], false)
				packet_size = max(packet_size, packet[connection['feature']].size())

		var hash = packet.hash()
		if packet_size > 0 and hash != last_packet_hash:
			target_plot.plot(packet, packet_size)

		target_plot.update_transform(plot_scale, plot_pos)

#endregion Virtuals


#region Auto Zoom

@export_group("Auto Zoom")
@export var zoom_enabled: bool = false
@export_range(0, 10) var zoom_target: int = 0
@export_exp_easing var zoom_speed := 0.01
@export_exp_easing var zoom_speed_threshold := 0.05
@export_subgroup('Top window')
@export var top_window_max := 1.0
@export var top_window_min := 0.0
@export var margin_top := 0.0
@export_subgroup('Bottom window')
@export var bot_window_max := 0.0
@export var bot_window_min := 0.0
@export var margin_bot := 0.0
@export_group("")
func smootherstep(t):
	return t * t * t * (t * (t * 6 - 15) + 10);

func ramp_up_lerp(from: float, to: float, speed: float, threshold: float):
	var delta := abs(to - from)
	var ratio := abs(delta / to)

	var mult := 1.0
	if ratio < threshold: mult = max(0, smootherstep(ratio / threshold))
	return lerp(from, to, speed + (speed * 10) * mult)

func auto_zoom():
	var target_plot: TimeGraph
	if zoom_target >= 0 and zoom_target < time_graphs.size():
		target_plot = time_graphs.values()[zoom_target]
	else: return

	if not target_plot.logger:
		target_plot._init_logger()
		target_plot.logging_enabled = true

	var logger := target_plot.logger
	logger._deque_window_size = maxi(10, plot_scale.x / 10.0 * 0.9 * logger._count - 10)

	var data_range := target_plot.logger.max - target_plot.logger.min
	var peak := clampf(target_plot.logger.max, top_window_min, top_window_max)
	var valley := clampf(target_plot.logger.min, bot_window_min, bot_window_max)
	peak += data_range * margin_top
	valley -= data_range * margin_bot
	plot_scale.y = ramp_up_lerp(plot_scale.y, peak - valley, zoom_speed / 100, zoom_speed_threshold)
	plot_pos.y = ramp_up_lerp(plot_pos.y, -valley, zoom_speed / 100, zoom_speed_threshold * 4)
#endregion Auto Zoom


#region Mouse Input

const MASK_BTN_LR := MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
const MASK_SCROLL := (8 | 16 | 32 | 64)
const MASK_SCROLL_UP_LEFT := (16 | 64)
var _initial_mouse_event_data: Array


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		_on_mouse_pressed(event)

	if event is InputEventMouseMotion:
		_on_mouse_motion(event)


func _on_mouse_pressed(event: InputEventMouseButton):
	var snapped_plot_pos := screen_to_plot(event.position, true)
	var screen_proportion := plot_to_screen(snapped_plot_pos, true)

	if event.button_mask & (MOUSE_BUTTON_LEFT | MOUSE_BUTTON_RIGHT):
		_initial_mouse_event_data = [
			event.position,
			Vector2(),
			plot_pos,
			plot_scale,
			screen_proportion
		]

	if event.button_mask & MASK_SCROLL:
		var direction: float = -1
		if event.button_mask & MASK_SCROLL_UP_LEFT: direction = 1

		var factor := pow(10, scroll_sensitivity) * 0.0015 * direction

		if not Input.is_key_pressed(KEY_SHIFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var new_scale_y: float = pow(10, log(plot_scale.y) / log(10) + factor)
			new_scale_y = clamp(new_scale_y, MIN_Y_SCALE, MAX_Y_SCALE)
			plot_pos.y -= (plot_scale.y - new_scale_y) * screen_proportion.y
			plot_scale.y = new_scale_y

		if draw_mode != DrawMode.Time \
			and not Input.is_key_pressed(KEY_CTRL) \
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var new_scale_x: float = pow(10, log(plot_scale.x) / log(10) + factor)
			new_scale_x = clamp(new_scale_x, MIN_X_SCALE, MAX_X_SCALE)
			plot_pos.x -= (plot_scale.x - new_scale_x) * screen_proportion.x
			plot_scale.x = new_scale_x


func _on_mouse_motion(event: InputEventMouseMotion):
	var data := _initial_mouse_event_data
	if not data.size(): return

	if event.button_mask & MASK_BTN_LR:
		data[1] = event.position - data[0]
	else: return

	if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var delta: Vector2 = data[1]
		if Input.is_key_pressed(KEY_SHIFT): delta = snap_to_axis(data[1], 0, 1)

		plot_pos.y = data[2].y + delta.y * data[3].y / size.y

		if draw_mode == DrawMode.Time:
			plot_scale.x = data[3].x + data[3].x * delta.x / max(0, size.x - event.position.x)
			plot_pos.x = plot_scale.x
		else:
			plot_pos.x = data[2].x + delta.x * data[3].x / size.x


	elif event.button_mask == MOUSE_BUTTON_MASK_RIGHT:
		if is_equal_approx(plot_scale.y, MIN_Y_SCALE) and event.relative.x > 0:
			return

		if is_equal_approx(plot_scale.y, MAX_Y_SCALE) and event.relative.x < 0:
			return
		if not Input.is_key_pressed(KEY_SHIFT):
			plot_scale.y = pow(10, log(data[3].y) / log(10) + data[1].x * -0.001)
			plot_pos.y = data[2].y - (data[3].y - plot_scale.y) * data[4].y

		if draw_mode != DrawMode.Time and not Input.is_key_pressed(KEY_CTRL):
			plot_scale.x = pow(10, log(data[3].x) / log(10) + data[1].x * -0.001)
			plot_pos.x = data[2].x - (data[3].x - plot_scale.x) * data[4].x

#endregion Mouse Input


#region Helpers


func get_or_add_time_graph(channel_name: StringName, sub_channel: int) -> TimeGraph:
	var id: StringName = &"%s_%d" % [channel_name, sub_channel]
	var time_graph: TimeGraph = time_graphs.get(id)
	if not time_graph:
		time_graph = TimeGraph.new()
		time_graph.color = channels[channel_name].color
		time_graph.init()
		time_graph_container.add_child(time_graph)
		time_graphs[id] = time_graph

	return time_graph


static func snap_to_axis(vector: Vector2, dist_threshold := 50, min_ratio := 2) -> Vector2:
	var mx := vector.abs().max_axis_index()
	var mn := abs(mx - 1)
	var ratio := abs(vector[mx] / vector[mn])

	if vector.length() > dist_threshold and ratio > min_ratio: vector[mn] = 0

	return vector


func screen_to_plot(pos: Vector2, quantize := false, to_ticks := true) -> Vector2:
	pos = pos / size * plot_scale - plot_pos

	if quantize: pos = grid.quantize(pos, to_ticks)

	return pos


func plot_to_screen(pos: Vector2, normalize := false) -> Vector2:
	pos.x = (pos.x + plot_pos.x) / plot_scale.x
	pos.y = (pos.y + plot_pos.y) / plot_scale.y
	if not normalize: pos *= size

	return pos
#endregion Helpers
