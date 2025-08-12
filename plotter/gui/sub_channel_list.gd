extends ToggleLabelList

const Channel = Plotter.Channel
@onready var offset_parent: MarginContainer = get_parent()
var plotter: Plotter
var label_count := Plotter.MAX_CHANNELS
var amount_visible: int


func _init(): _clear_on_ready = true


func init(plotter_node: Plotter):
	plotter = plotter_node
	mode = Mode.Single

	for i in label_count:
		var label := create_label(str(i + 1), i)
		label.indicator_mode = ToggleLabel.IndicatorMode.WhenToggled
		label.use_bottom_indicator = true
		label.visible = false


func update_visuals(parent_label: ToggleLabel):
	amount_visible = 0
	var color := Color.WEB_GREEN

	if parent_label and parent_label.is_toggled:
		offset_parent.add_theme_constant_override("margin_top", max(0, parent_label.position.y))
		var channel_size := plotter.channels[parent_label.meta].channels.size()
		color = parent_label.color


		if channel_size > 1:
			amount_visible = channel_size

	for i in labels.size():
		labels.values()[i].visible = i < amount_visible
		labels.values()[i].color = color
