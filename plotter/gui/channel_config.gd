extends Control

signal average_changed(average: float)
signal sub_channel_toggled(channel: Plotter.Channel, sub_channel: int, is_toggled: bool)
signal sub_channels_initialized

const ICON_INVISIBLE = preload("uid://bxap0iae66i5w")
const ICON_VISIBLE = preload("uid://fg851iaq6c06")

@onready var main_container: BoxContainer = $MainContainer
@onready var sub_channel_list: ToggleLabelList = %SubChannelList
@onready var average_swiper: Control = %AverageSwiper

var channel: Plotter.Channel
var is_enabled: bool: set = _set_enabled
var plotter: Plotter


func _ready():
	_set_enabled(is_enabled)
	sub_channel_list.mode = ToggleLabelList.Mode.Multi
	plotter.channels_changed.connect(_on_channels_changed)
	sub_channel_list.was_toggled.connect(func(l): sub_channel_toggled.emit(channel, l.meta, l.is_toggled))
	average_swiper.value_changed.connect(average_changed.emit)


func _on_channels_changed():
	var label_count: int = sub_channel_list.labels.size()
	var channel_count: int = channel.channels.size()
	var connections: Array = plotter.state.find(
		{'feature': Plotter.Feature.Y, 'channel': channel
	}, true)
	var sub_channels: Array = connections.map(func(c): return c['sub_channel'])

	for c in range(label_count, channel_count):
		var label := sub_channel_list.create_label(str(c + 1), c)
		label.color = channel.color
		label.indicator_mode = ToggleLabel.IndicatorMode.WhenToggled
		label.use_bottom_indicator = true
		if c in sub_channels:
			sub_channel_list.add_to_multi_selection(label, false)
		else:
			sub_channel_list.remove_from_multi_selection(label, false)

	for c in range(channel_count - 1, label_count, -1):
		sub_channel_list.destroy_label(sub_channel_list.labels.values()[c])

	sub_channels_initialized.emit()

func _set_enabled(new_state: bool):
	is_enabled = new_state
	main_container.visible = new_state
