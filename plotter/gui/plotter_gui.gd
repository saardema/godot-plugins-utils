# @tool
extends MarginContainer

const ToggleLabelList = preload("components/toggle_label/toggle_label_list.gd")
const Feature = Plotter.Feature
const Channel = Plotter.Channel
var plotter: Plotter

@onready var transform_display: Label = %TransformDisplay
@onready var popup_menu_draw_mode: PopupMenu = %PopupMenuDrawMode
@onready var channel_list: ToggleLabelList = %ChannelList
@onready var time_channel_list: ToggleLabelList = %TimeChannelList
@onready var sub_channel_list: ToggleLabelList = %SubChannelList
@onready var feature_list: ToggleLabelList = %FeatureList
@onready var button_features: Button = %ButtonFeatureConfig
@onready var button_channels: Button = %ButtonChannels
@onready var button_channel_config: Button = %ButtonChannelConfig


func init():
	plotter = get_parent()
	plotter.transform_changed.connect(update_transform_display)

	feature_list.set_child_list(channel_list)
	channel_list.set_child_list(sub_channel_list)

	# Feature list
	feature_list.init(plotter)
	button_features.toggled.connect(_on_button_features_toggled)
	button_features.button_pressed = feature_list.visible

	# Channel list
	channel_list.init(plotter)
	button_channels.toggled.connect(_on_button_channels_toggled)
	button_channels.button_pressed = channel_list.visible

	# Time channel list
	time_channel_list.init(plotter, button_channel_config)

	# Sub channel list
	sub_channel_list.init(plotter)

	# Draw mode menu
	plotter.draw_mode_changed.connect(_on_draw_mode_changed)
	popup_menu_draw_mode.id_pressed.connect(
		func(id): plotter.draw_mode = Plotter.DrawMode.values()[id]
	)

	_init_draw_mode_menu()
	_on_draw_mode_changed()
	update_transform_display()


func _on_button_features_toggled(is_toggled: bool):
	if plotter.draw_mode == Plotter.DrawMode.Time:
		button_channel_config.visible = is_toggled
		time_channel_list.visible = is_toggled
	else:
		sub_channel_list.visible = is_toggled and button_channels.button_pressed
		feature_list.visible = is_toggled
		channel_list.visible = is_toggled and button_channels.button_pressed
		button_channels.visible = is_toggled


func _on_button_channels_toggled(is_toggled: bool):
	channel_list.visible = is_toggled
	sub_channel_list.visible = is_toggled


func update_transform_display():
	var precision := Vector2i(
		clamp(3 - ceili(log(abs(plotter.plot_scale.x)) / log(10)), 0, 8),
		clamp(3 - ceili(log(abs(plotter.plot_scale.y)) / log(10)), 0, 8)
	)

	transform_display.text = '[%*.*f, %*.*f], [%0.*f, %0.*f]' % [
		precision.x + 3, precision.x, plotter.plot_pos.x,
		precision.y + 3, precision.y, plotter.plot_pos.y,
		precision.x, plotter.plot_scale.x,
		precision.y, plotter.plot_scale.y
	]


func _init_draw_mode_menu():
	for id in Plotter.DrawMode.values():
		popup_menu_draw_mode.add_radio_check_item(Plotter.DrawMode.keys()[id], id)


func _on_draw_mode_changed():
	for id in Plotter.DrawMode.values():
		popup_menu_draw_mode.set_item_checked(id, id == plotter.draw_mode)
	popup_menu_draw_mode.title = Plotter.DrawMode.keys()[plotter.draw_mode]

	if plotter.draw_mode == Plotter.DrawMode.Time:
		# channel_list.mode = ToggleLabelList.Mode.Multi
		# sub_channel_list.mode = ToggleLabelList.Mode.Multi
		feature_list.visible = false
		time_channel_list.visible = true
		sub_channel_list.visible = false
		channel_list.visible = false
		feature_list.visible = false
		button_channel_config.visible = true
		button_channels.visible = false
	else:
		# channel_list.mode = ToggleLabelList.Mode.SingleOrNone
		# sub_channel_list.mode = ToggleLabelList.Mode.Single
		feature_list.visible = true
		time_channel_list.visible = false
		sub_channel_list.visible = true
		channel_list.visible = true
		feature_list.visible = true
		button_channel_config.visible = false
		button_channels.visible = true
