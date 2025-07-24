@tool
extends MarginContainer

const ToggleLabelList = preload("toggle_label_list.gd")
const Feature = Plotter.Feature
const Channel = Plotter.Channel
var plotter: Plotter

@onready var popup_menu_draw_mode: PopupMenu = %PopupMenuDrawMode
@onready var channel_list: ToggleLabelList = %ChannelList
@onready var feature_list: ToggleLabelList = %FeatureList
@onready var button_features: Button = %ButtonFeatureConfig
@onready var button_channels: Button = %ButtonChannels


func init():
	plotter = get_parent()

	# Feature list
	feature_list.init(plotter)
	feature_list.single_selection_changed.connect(_feature_selection_change)
	feature_list.selection_mode = ToggleLabelList.SelectionMode.Single
	button_features.toggled.connect(func(on): feature_list.visible = on)
	button_features.button_pressed = feature_list.visible

	# Channel list
	channel_list.init(plotter)
	channel_list.single_selection_changed.connect(_on_channel_selection_change)
	channel_list.selection_mode = ToggleLabelList.SelectionMode.SingleOrNone
	button_channels.toggled.connect(func(on): channel_list.visible = on)
	button_channels.button_pressed = channel_list.visible

	# Draw mode menu
	plotter.draw_mode_changed.connect(_on_draw_mode_changed)
	popup_menu_draw_mode.id_pressed.connect(
		func(id): plotter.draw_mode = Plotter.DrawMode.values()[id]
	)

	#plotter.state.loaded.connect(func(connection: ConnectionsState.Connection):
		#if feature_list.id_to_label_map.has(connection.feature):
			#var feature_label := feature_list.id_to_label_map[connection.feature as Variant]
			#feature_label.set_background_color(connection.channel.color if connection.channel else null)
			#_feature_selection_change(connection.feature as Feature)
	#)

	_init_draw_mode_menu()


func _on_channel_selection_change(channel_name: Variant):
	var feature := feature_list.current_single_selection as Feature
	var state_changed := true
	var channel: Plotter.Channel

	if channel_name is StringName and plotter.channels.has(channel_name):
		channel = plotter.channels[channel_name]

		var connection: Plotter.Connection

		if plotter.state.connections.has(feature):
			connection = plotter.state.connections[feature]

			if connection.channel.channel_name == channel_name and \
				connection.sub_channel == 0:
				state_changed = false

		else:
			connection = Plotter.Connection.new()

		connection.channel = channel
		connection.sub_channel = 0
		connection.feature = feature
		plotter.state.connections[feature] = connection

	else:
		if plotter.state.connections.has(feature):
			plotter.state.connections.erase(feature)
		else: state_changed = false

	if state_changed:
		plotter.state.save(true)

	# var feature_label := feature_list.id_to_label_map[feature as Variant]
	# feature_label.set_background_color(channel.color if channel else null)

	# print(plotter.state.connections)


func _feature_selection_change(feature: Feature):
	var connected_channels: Array[Variant] = []

	if plotter.state.connections.has(feature):
		connected_channels.append(plotter.state.connections[feature].channel.channel_name)

	channel_list.set_selection_from_ids(connected_channels)


func _init_draw_mode_menu():
	for id in Plotter.DrawMode.values():
		popup_menu_draw_mode.add_radio_check_item(Plotter.DrawMode.keys()[id], id)
		if id == plotter.draw_mode: popup_menu_draw_mode.set_item_checked(id, true)


func _on_draw_mode_changed():
	for id in Plotter.DrawMode.values():
		popup_menu_draw_mode.set_item_checked(id, id == plotter.draw_mode)
