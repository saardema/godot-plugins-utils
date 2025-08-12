class_name StateInstance
extends Resource

var connections: Dictionary[Plotter.Feature, Plotter.Connection]
@export var state: Dictionary

func serialize_connections():
	state['connections'] = {}

	for feature in connections.keys():
		state['connections'][feature] = {
			"feature": feature,
			"channel_name": connections[feature].channel.name,
			"sub_channel": connections[feature].sub_channel
		}


func serialize():
	state.clear()
	serialize_connections()

func unpack_channel(channel: Plotter.Channel):
	if state.is_empty(): return

	for connection_data in state["connections"].values():
		if not channel.name != connection_data["channel_name"]: continue

		var connection := Plotter.Connection.new()
		connection.feature = connection_data["feature"]
		connection.channel = channel
		connection.sub_channel = connection_data["sub_channel"]

		connections[connection.feature] = connection

func deserialize(channels: Dictionary[StringName, Plotter.Channel]):
	if state.is_empty(): return

	connections.clear()

	for data in state["connections"].values():
		if not channels.has(data["channel_name"]): continue

		var connection := Plotter.Connection.new()
		connection.feature = data["feature"]
		connection.channel = channels[data["channel_name"]]
		connection.sub_channel = data["sub_channel"]

		connections[connection.feature] = connection
