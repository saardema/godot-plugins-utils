# @tool
extends Plot

const Plot = preload('../plot.gd')

@onready var renderer: Control = %Renderer
@onready var sub_viewport: SubViewport = %SubViewport

@export var persistence: bool:
	set(v):
		persistence = v
		if not sub_viewport: return
		if persistence:
			sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		else:
			sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS

func init(plot_color := Color.WHITE):
	use_individual_sizes = true
	super.init(plot_color)
	clear()
	resized.connect(blank)

	if persistence:
		sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	else:
		sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS


func clear():
	points.clear()
	visible_point_count = 0
	buffer_size = 0
	blank()


func plot(packet: Dictionary[Feature, PackedFloat32Array], content_size: int):
	super.plot(packet, content_size)


func blank():
	if persistence:
		sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE


func update_transform(scale_in: Vector2, pos_in: Vector2):
	if plot_scale != scale_in or plot_position != pos_in:
		plot_scale = scale_in
		plot_position = pos_in
		blank()

	renderer.queue_redraw()
