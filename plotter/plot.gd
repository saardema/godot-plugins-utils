class_name Plot
extends Control

var logger: DataLogger
var segments: Array[PackedVector2Array]
var segment_scales: PackedVector2Array
var segment_idx: int
var color: Color
var needle: float
var point_idx: int
var plot_scale: Vector2
var plot_position: Vector2
var last_scale: Vector2
const resolution: int = 60
const inv_resolution: float = 1.0 / resolution
var segment_count: int = 10
var logging_enabled: bool = true
const line_width: int = 3
var update_timer: float
var plot_name: String

func _init():
	visibility_changed.connect(_on_visibility_changed)
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _on_visibility_changed():
	if not visible:
		segment_idx = 0
		point_idx = 0
		plot_position.x = 0
		for s in segments:
			s.clear()
			s.resize(resolution + 1)
		segments[0].fill(Vector2(size.x / plot_scale.x, 0))


func init(name_: String, plot_color := Color.WHITE):
	plot_name = name_
	color = plot_color
	logger = DataLogger.new(resolution * segment_count, 1000.0 / resolution, 0)
	logger.average_range = 0.05 * resolution * segment_count
	resized.connect(rescale)
	segment_scales.resize(segment_count + 1)
	for v in segment_count + 1:
		segments.append(PackedVector2Array())
		segments[v].resize(resolution + 1)


func set_needle(value: float):
	needle = value


func scroll(delta: float, at_scale: Vector2, y_offset: float):
	if resolution == 0:
		push_error('Plot not initialized. Resolution is 0')
		return

	plot_position.y = y_offset
	plot_position.x += delta

	update_timer -= delta
	if update_timer < 0:
		update_timer += inv_resolution
		step()

	plot_scale = at_scale
	if plot_scale != last_scale: rescale()
	last_scale = plot_scale

	queue_redraw()


func step():
	if logging_enabled: logger.append(needle)

	if point_idx == resolution:
		_add_point(plot_position.x, -needle)
		point_idx = 0
		segment_idx = (segment_idx + 1) % (segment_count + 1)
		segment_scales[segment_idx] = size / plot_scale
		plot_position.x = 0
		segments[segment_idx].fill(Vector2(INF, 0))

	_add_point(plot_position.x, -needle)

	point_idx = (point_idx + 1) % (resolution + 1)


func _add_point(x: float, y: float):
	var vector := Vector2(x, y) * segment_scales[segment_idx]
	segments[segment_idx][point_idx] = vector


func rescale():
	var value: float
	var update_range: int = mini(segment_count + 1, plot_scale.x + 3)
	update_range = mini(update_range, segments.size())
	update_range = mini(update_range, segment_scales.size())

	for p in update_range:
		var rsidx: int = segment_idx - p
		var factor := segment_scales[rsidx] / size * plot_scale
		for v in resolution + 1: segments[rsidx][v] /= factor
		segment_scales[rsidx] = size / plot_scale


func _draw():
	if segments.size() == 0: return


	var pos := plot_position
	pos.x -= inv_resolution * 2

	for v in ceili(plot_scale.x + 1):
		var sidx: int = (segment_idx + segment_count + 1 - v) % (segment_count + 1)
		var tfp := pos * size / plot_scale
		tfp.x = size.x - tfp.x
		draw_set_transform(tfp, 0, Vector2(1, 1))
		draw_polyline(segments[sidx], color, line_width, true)
		pos.x += 1
