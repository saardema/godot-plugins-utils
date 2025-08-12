extends ToggleLabelList

const Feature = Plotter.Feature

var plotter: Plotter
var connections: Dictionary[StringName, Dictionary]
var channel_list: ToggleLabelList
var sub_channel_list: ToggleLabelList


func _init(): _clear_on_ready = true


func init(plotter_node: Plotter):
	plotter = plotter_node
	connections = plotter.state.connections
	channel_list = child_list
	sub_channel_list = channel_list.child_list

	plotter.channels_changed.connect(_on_channels_changed)
	plotter.draw_mode_changed.connect(_on_draw_mode_changed)
	was_toggled.connect(_on_feature_toggled)
	channel_list.was_toggled.connect(_on_channel_toggled)
	sub_channel_list.was_toggled.connect(_on_sub_channel_toggled)

	build_list()
	update_hash(get_outer_hash())


func _on_feature_toggled(label: ToggleLabel):
	update_channel_label()


func _on_channel_toggled(label: ToggleLabel):
	update_sub_channel_label()
	set_connection()
	update_backgrounds()


func _on_sub_channel_toggled(label: ToggleLabel):
	set_connection()
	update_backgrounds()


func _on_channels_changed():
	update_channel_label()


func set_connection():
	for id in plotter.state.find({'feature': selected_meta}):
		plotter.state.remove_connection(id)

	if channel_list.selected_meta and sub_channel_list.selected_meta != null:
		plotter.state.add_connection(
			selected_meta,
			channel_list.selected_meta,
			sub_channel_list.selected_meta
		)


func get_outer_hash() -> StringName:
	var index: int = plotter.draw_mode if plotter else 0
	return Plotter.DrawMode.keys()[index].to_lower()


func update_backgrounds():
	for label in labels.values():
		var channel = plotter.state.get_channel(label.meta)

		if channel:
			label.color = channel.color
			label.indicator_mode = ToggleLabel.IndicatorMode.Show
		else:
			label.indicator_mode = ToggleLabel.IndicatorMode.Hide


func update_channel_label():
	var channel = plotter.state.get_channel(selected_label.meta)
	channel_list.select(channel.name if channel else null, true, true)


func update_sub_channel_label():
	sub_channel_list.select(null, false, false)


func _on_draw_mode_changed():
	build_list()
	update_hash(get_outer_hash())
	update_channel_label()


func build_list():
	clear_labels()

	for feature in plotter.draw_mode_features[plotter.draw_mode]:
		var text: String = Plotter.Feature.keys()[feature]
		var label := create_label(text, feature)
		label.indicator_mode = ToggleLabel.IndicatorMode.Show
		label.use_bottom_indicator = true
