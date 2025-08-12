extends ToggleLabelList

const Channel = Plotter.Channel
const Feature = Plotter.Feature

var plotter: Plotter


func _init(): _clear_on_ready = true


func init(plotter_node: Plotter):
	plotter = plotter_node
	plotter.channel_added.connect(_on_channel_added)
	plotter.channel_removed.connect(_on_channel_removed)
	plotter.channels_changed.connect(_on_channels_changed)
	mode = Mode.SingleOrNone
	was_toggled.connect(_on_toggled)


func _on_toggled(label: ToggleLabel):
	child_list.update_visuals(label)


func _on_channels_changed():
	child_list.update_visuals(selected_label)


func _on_channel_added(channel: Channel):
	var label := create_label(channel.name, channel.name)
	label.color = channel.color
	label.indicator_mode = ToggleLabel.IndicatorMode.WhenToggled


func _on_channel_removed(channel_name: StringName):
	destroy_label(labels[channel_name as Variant])
