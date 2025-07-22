## Stores and provides an arbitrary stream of scalar or multidimensional float data
# Data contained is flushed when read

class_name PlotChannel

const PlotBaseChannel = preload('plot_base_channel.gd')

var channels: Array[PlotBaseChannel]
var channel_name: StringName
var color := Color.WHITE
var enabled: bool = true
var channel_count: int = 1

var max_size: int = 256:
	set(v):
		max_size = clamp(v, 1, 2048)

func _init(name: StringName, sub_channels := 2, max_buffer_size := 256):
	channel_count = sub_channels
	max_size = max_buffer_size
	channel_name = name

	for i in sub_channels:
		var sub_name := "%s (%d)" % [channel_name, i + 1]
		var sub_channel := PlotBaseChannel.new(sub_name, max_buffer_size)
		sub_channel.color = color
		channels.append(sub_channel)


func is_full() -> bool:
	for channel in channels:
		if not channel.is_full():
			return false
	return true


func flush():
	for channel in channels:
		channel.flush()


func read_single(channel: int = 0) -> float:
	if channels.size() == 0: return 0.0

	return channels[channel].read_single()


func write_single(value: float, channel: int):
	channels[channel].write_single(value)


func write_singles(values: PackedFloat32Array):
	if values.size() != channels.size():
		push_warning("Values size does not match channel count")
		values.resize(channels.size())

	for i in channels.size():
		channels[i].write_single(values[i])


func set_buffer(new_buffer: PackedFloat32Array, channel: int):
	if new_buffer.size() > channels[channel].max_size:
		push_warning("New buffer size exceeds max_size. Resizing to match.")
		new_buffer.resize(channels[channel].max_size)

	channels[channel].set_buffer(new_buffer)


func get_buffer(channel: int) -> PackedFloat32Array:
	return channels[channel].get_buffer()
