extends ToggleLabelList

const CHANNEL_CONFIG = preload("uid://hsa83lys32tm")
const Channel = Plotter.Channel
const Feature = Plotter.Feature

var plotter: Plotter
var channel_menu_map: Dictionary[StringName, Dictionary]
var button_channel_config: Button

func init(plotter_node: Plotter, button_config: Button):
	plotter = plotter_node
	plotter.channel_added.connect(_on_channel_added)
	plotter.channel_removed.connect(_on_channel_removed)
	mode = Mode.Single
	was_toggled.connect(_toggle_config_visibility)
	button_channel_config = button_config
	button_channel_config.toggled.connect(_toggle_config_visibility)


func _toggle_config_visibility(_p = null):
	for data in channel_menu_map.values():
		data['config'].is_enabled = data['label'].is_toggled and button_channel_config.button_pressed


func _on_sub_channel_toggled(channel: Channel, sub_channel: int, is_toggled: bool, config: Control):
	if is_toggled:
		plotter.state.add_connection(
			Plotter.Feature.Y,
			channel.name,
			sub_channel
		)
	else:
		plotter.state.remove_connection(Plotter.Feature.Y, channel.name, sub_channel)
	_on_sub_channels_changed(config)


func _on_sub_channels_changed(config: Control):
	var label: ToggleLabel = channel_menu_map[config.channel.name]['label']
	if config.sub_channel_list.selected_labels.size() > 0:
		label.indicator_mode = ToggleLabel.IndicatorMode.Show
	else: label.indicator_mode = ToggleLabel.IndicatorMode.Hide


func _on_channel_added(channel: Channel):
	var config := CHANNEL_CONFIG.instantiate()
	config.channel = channel
	config.plotter = plotter
	config.sub_channel_toggled.connect(_on_sub_channel_toggled.bind(config))
	config.sub_channels_initialized.connect(_on_sub_channels_changed.bind(config))
	config.average_changed.connect(_on_average_changed.bind(config))
	add_child(config)

	var label := create_label(channel.name, config)
	label.color = channel.color
	label.indicator_mode = ToggleLabel.IndicatorMode.Hide

	channel_menu_map[channel.name] = {'config': config, 'label': label}
	_toggle_config_visibility()

func _on_channel_removed(channel_name: StringName):
	destroy_label(labels[channel_name as Variant])


func _on_average_changed(average: float, config: Control):
	plotter.get_or_add_time_graph(config.channel.name, 0).averaging = average
