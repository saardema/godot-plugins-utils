## Stores and provides an arbitrary stream of scalar or multidimensional float data
# Data contained is flushed when read

signal sub_channel_added(channel: BaseChannel)
signal sub_channel_removed(channel_name: StringName)

const BaseChannel = preload('base_channel.gd')

var channels: Array[BaseChannel]
var channel_name: StringName
var color := Color.WHITE
var enabled: bool = true

var max_size: int = 256:
	set(v):
		max_size = clamp(v, 1, 2048)

func _init(name: StringName, sub_channels := 2, max_buffer_size := 256):
	max_size = max_buffer_size
	channel_name = name
	for i in sub_channels: add_sub_channel()


func add_sub_channel():
	var sub_name := "%s (%d)" % [channel_name, channels.size() + 1]
	var sub_channel := BaseChannel.new(sub_name, max_size)
	sub_channel.color = color
	channels.append(sub_channel)
	sub_channel_added.emit(sub_channel)


func set_channel_count(count: int):
	if count < 1:
		push_warning("Channel count must be at least 1")
		return

	if count > channels.size():
		for i in count - channels.size():
			add_sub_channel()

	elif count < channels.size():
		for i in channels.size() - count:
			var removed_channel := channels.pop_back()
			sub_channel_removed.emit(removed_channel.channel_name)


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
