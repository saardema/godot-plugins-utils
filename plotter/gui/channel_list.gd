@tool
extends ToggleLabelList
const Channel = Plotter.Channel
const ToggleLabelList = preload("toggle_label_list.gd")

var plotter: Plotter


func init(plotter_node: Plotter):
	plotter = plotter_node

	plotter.channel_added.connect(_on_channel_added)
	plotter.channel_removed.connect(_on_channel_removed)


func _on_channel_added(channel: Channel):
	var label := create_label(channel.channel_name, channel.channel_name, false, true, channel.color)


func _on_channel_removed(channel_name: StringName):
	destroy_label(id_to_label_map[channel_name as Variant])
