# # @tool
# class_name Connection
# extends Resource

var feature: Plotter.Feature
var channel: Plotter.Channel
var sub_channel: int = 0
# @export var channel_name: StringName

# func _init():
# 	resource_local_to_scene = true


# func get_channel(channels: Dictionary[StringName, Plotter.Channel]) -> Plotter.Channel:
# 	if not channels.has(channel_name): return null
# 	if not channel: channel = channels[channel_name]
# 	return channel

# func read_single(channels: Dictionary[StringName, Plotter.Channel]) -> float:
# 	if not channels.has(channel_name): return 0.0
# 	return channels[channel_name].read_single(sub_channel)

func get_buffer(): return channel.get_buffer(sub_channel)
