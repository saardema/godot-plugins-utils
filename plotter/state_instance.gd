class_name StateInstance
extends Resource

var connections: Dictionary[Plotter.Feature, Plotter.Connection]
var is_deserialized: bool
@export var state: Dictionary

func serialize_connections():
	state['connections'] = {}

	for feature in connections.keys():
		state['connections'][feature] = {
			"feature": feature,
			"channel_name": connections[feature].channel.channel_name,
			"sub_channel": connections[feature].sub_channel
		}


func serialize():
	state.clear()
	serialize_connections()


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
