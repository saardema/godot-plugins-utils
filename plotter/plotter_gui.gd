extends Control

signal connections_changed
signal connection_made(connection: Dictionary)
signal connection_removed(feature: Plotter.PlotFeature, channel: PlotChannel, sub_channel: int)

@onready var label_container: FlowContainer = %LabelContainer
@onready var button_channels: Button = %ButtonChannels
@onready var popup_menu_features_to_channels: PopupMenu = %PopupMenuPlotWiring
@onready var popup_menu_plot_mode: PopupMenu = %PopupMenuPlotMode

var plotter: Plotter
var map_features_menu: Dictionary[PopupMenu, Dictionary] = {}
var channels_map: Dictionary[StringName, PlotChannel]
var feature_stream_relations: Dictionary

func _ready():
	plotter = get_parent()

	button_channels.pressed.connect(_on_button_channels_pressed)
	popup_menu_plot_mode.id_pressed.connect(_on_draw_mode_clicked)
	plotter.draw_mode_changed.connect(_on_draw_mode_changed)
	plotter.channel_added.connect(_add_channel)
	plotter.channel_removed.connect(_remove_channel)
	_init_draw_mode_menu()
	_populate_feature_menu_items()


func _on_draw_mode_changed():
	for id in Plotter.DrawMode.values():
		popup_menu_plot_mode.set_item_checked(id, id == plotter.draw_mode)

	_populate_feature_menu_items()

func _on_button_channels_pressed():
	label_container.visible = not label_container.visible

func _on_draw_mode_clicked(id: int):
	plotter.draw_mode = Plotter.DrawMode.values()[id]


func _add_channel(channel: PlotChannel):
	channels_map[channel.channel_name] = channel

	for feature_menu: PopupMenu in map_features_menu.keys():
		var channels: Dictionary = map_features_menu[feature_menu]
		if channels.has(channel.channel_name):
			push_warning("Channel '%s' already exists in '%s' menu" % [channel.channel_name, feature_menu.title])
			continue
		var channel_id: int = channels.size() - 1
		if channel.channel_count > 1:
			var submenu: PopupMenu = _create_channel_menu_item(channel, channels['feature_id'], channel_id)
			feature_menu.add_submenu_node_item(channel.channel_name, submenu)
		else:
			feature_menu.add_radio_check_item(channel.channel_name, channel_id << 8 | 1)
		channels[channel.channel_name] = -1


func _remove_channel(channel_name: StringName):
	for feature_menu in map_features_menu.keys():
		map_features_menu[feature_menu].erase(channel_name)

		for i in feature_menu.item_count:
			if feature_menu.get_item_text(i) == channel_name:
				feature_menu.remove_item(i)
				break

	channels_map.erase(channel_name)

func _init_draw_mode_menu():
	for id in Plotter.DrawMode.values():
		popup_menu_plot_mode.add_radio_check_item(Plotter.DrawMode.keys()[id], id)
		if id == plotter.draw_mode: popup_menu_plot_mode.set_item_checked(id, true)

func _create_channel_menu_item(channel: PlotChannel, feature: Plotter.PlotFeature, channel_id: int) -> PopupMenu:
	var submenu := PopupMenu.new()
	submenu.title = "%s (%d)" % [channel.channel_name, channel.channel_count]
	submenu.id_pressed.connect(_on_connection_click.bind(feature))
	for i in channel.channels.size():
		submenu.add_check_item("Stream " + str(i + 1), (channel_id << 8) | i + 1)

	return submenu

func _on_connection_click(relation_id: int, feature: Plotter.PlotFeature):
	DebugTools.write(
		'gui',
		"relation_id %d, feature %d, channel %d, stream %d" %
		[relation_id, feature, relation_id >> 8, (relation_id & 0xFF) - 1],
		true
	)

	if relation_id == 0:
		plotter.connections.erase(feature)
		connection_removed.emit(feature)
		# DebugTools.print('Connection removed: feature %d' % [feature])
		return

	var channel: PlotChannel = channels_map.values()[relation_id >> 8]
	var sub_channel: int = (relation_id & 0xFF) - 1

	plotter.connections[feature] = {
		'channel': channel,
		'sub_channel': sub_channel
	}

	connection_made.emit()


func _populate_feature_menu_items():
	popup_menu_features_to_channels.clear(true)
	map_features_menu.clear()

	for feature in Plotter.draw_mode_features[plotter.draw_mode]:
		var submenu := PopupMenu.new()
		submenu.id_pressed.connect(_on_connection_click.bind(feature))
		submenu.title = Plotter.PlotFeature.keys()[feature]
		map_features_menu[submenu] = {'feature_id': feature}
		submenu.add_check_item("None", 0)
		popup_menu_features_to_channels.add_submenu_node_item(submenu.title, submenu)

	for channel in plotter.channels.values(): _add_channel(channel)
