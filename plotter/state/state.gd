extends Resource

signal connected(feature: Feature, channel: Channel, sub_channel: int)
signal disconnected(feature: Feature, channel: Channel, sub_channel: int)

const Feature = Plotter.Feature
const Channel = Plotter.Channel

@export var connections: Dictionary[StringName, Dictionary]
var pending_connections: Array[Dictionary]
var channels: Dictionary[StringName, Channel]
var plotter: Plotter


func _init(plotter_ref: Plotter):
	plotter = plotter_ref
	channels = plotter_ref.channels
	plotter.channels_changed.connect(_on_channels_changed)

	if plotter.name == 'IOPlotter':
		pending_connections = [
			{
				"feature": Feature.X,
				"channel_name": "Input",
				"sub_channel": 0
			},
			{
				"feature": Feature.Y,
				"channel_name": "Expected",
				"sub_channel": 0
			},
			{
				"feature": Feature.Color,
				"channel_name": "Input",
				"sub_channel": 0
			}
		]
	else:
		pending_connections = [
			{
				"feature": Feature.Y,
				"channel_name": "Loss",
				"sub_channel": 0
			},
		]


func always_true(_k, _d): return true
func always_false(_k, _d): return false
func return_value(_k, _d): return _d[_k]
func negate_value(_k, _d): return not _d[_k]
func test_filter():
	var dict = {
		0: false,
		1: true,
	}
	print('\n')
	printt(
		_filter_and(dict, [always_true, return_value]),
		_filter_and(dict, [always_true, return_value], [1, 1]),
		_filter_and(dict, [always_false, return_value]),
		_filter_and(dict, [always_false, return_value], [1, 1])
	)
	printt(
		_filter_and2(dict, [always_true, return_value]),
		_filter_and2(dict, [always_true, return_value], [1, 1]),
		_filter_and2(dict, [always_false, return_value]),
		_filter_and2(dict, [always_false, return_value], [1, 1])
	)


func get_hash(arg0, channel_name: StringName = &"", sub_channel: int = 0) -> StringName:
	var feature = arg0

	if arg0 is Dictionary:
		feature = arg0['feature']
		channel_name = arg0['channel_name']
		sub_channel = arg0['sub_channel']

	return '%s_%s_%d' % [Plotter.Feature.keys()[feature], channel_name, sub_channel]


func set_connection_by_dict(connection: Dictionary):
	add_connection(connection['feature'], connection['channel_name'], connection['sub_channel'])


func _sanitize(feature: Feature, channel_name: StringName, sub_channel: int = 0) -> Dictionary:
	if not channels.has(channel_name):
		push_warning('Cannot add connection: Channel "%s" does not exist' % channel_name)
		return {}

	if channels[channel_name].channels.size() - 1 < sub_channel:
		push_warning('Cannot add connection: sub channel (%d) out of range' % [sub_channel])
		return {}

	if feature not in Plotter.Feature.values():
		push_warning('Cannot add connection: Feature (%d) does not exist' % [feature])
		return {}

	return {
		"feature": feature,
		"channel": channels[channel_name],
		"channel_name": channel_name,
		"sub_channel": sub_channel
	}

## Connect channel to feature, if connection is valid
##
## add_connection(id: StringName)
## add_connection(connection: Dictionary)
## add_connection(feature: Feature, channel_name: StringName, sub_channel: int = 0)
func add_connection(arg0, channel_name: StringName = &"", sub_channel: int = 0):
	var feature = arg0
	var id: StringName

	if arg0 is Dictionary:
		feature = arg0['feature']
		channel_name = arg0['channel_name']
		sub_channel = arg0['sub_channel']

	elif arg0 is StringName:
		id = arg0

	else:
		id = get_hash(feature, channel_name, sub_channel)

	var connection := _sanitize(feature, channel_name, sub_channel)
	if not connection: return

	if connections.get(id) == connection:
		push_warning('Cannot add connection: "%s" already exists' % id)
		return

	connections[id] = connection
	connected.emit(feature, channel_name, sub_channel)

	# print('Connecting %s to %s (%d)' % [
	# 	Plotter.Feature.keys()[connection['feature']],
	# 	connection['channel_name'],
	# 	connection['sub_channel']
	# ])


func remove_connection(arg0, channel_name: StringName = &"", sub_channel: int = 0):
	var feature = arg0
	var id: StringName

	if arg0 is Dictionary:
		feature = arg0['feature']
		channel_name = arg0['channel_name']
		sub_channel = arg0['sub_channel']

	elif arg0 is StringName:
		id = arg0

	else:
		id = get_hash(feature, channel_name, sub_channel)

	var connection := connections.get(id)

	if not connection:
		push_warning('Cannot remove connection: "%s" does not exist' % id)
		return

	connections.erase(id)
	disconnected.emit(connection['feature'], connection['channel'], connection['sub_channel'])

	# print('Disconnecting %s from %s (%d)' % [
	# 	Plotter.Feature.keys()[connection['feature']],
	# 	connection['channel_name'],
	# 	connection['sub_channel']
	# ])


func _on_channels_changed():
	for key in _filter_or(connections, [channel_exists, sub_channel_exists], [1]):
		remove_connection(key)

	for connection in _filter_and(pending_connections, [connection_exists, channel_exists, sub_channel_exists], [1, 0, 0]):
		set_connection_by_dict(connection)

func get_channel(feature: Feature):
	var query := {'feature': feature}
	var connection = find_one(query, true)

	return connection['channel'] if connection else null


#region Filtering
func find_one(query: Dictionary, hydrate: bool = false):
	var ids := find(query)
	if ids.size() == 0: return null

	return connections[ids[0]] if hydrate else ids[0]

func find(query: Dictionary, hydrate: bool = false) -> Array:
	var ids := connections.keys()
	for key in query:
		ids = ids.filter(func(id):
			return matches(connections[id], [key, query[key]])
		)
	if hydrate: return ids.map(func(id): return connections[id])

	return ids

func matches(connection: Dictionary, query: Array) -> bool:
	if query[1] is Array:
		for value in query[1]:
			if matches(connection, [query[0], value]): return true
		return false
	return connection[query[0]] == query[1]

func sub_channel_exists(connection: Dictionary) -> bool:
	var channel: Channel = channels.get(connection['channel_name'])
	if channel == null: return false
	return connection['sub_channel'] <= channel.channels.size() - 1

func channel_exists(connection: Dictionary) -> bool:
	return channels.has(connection['channel_name'])

func connection_exists(connection: Dictionary) -> bool:
	return connections.has(get_hash(connection))

func _filter_or2(dict: Dictionary, conditions: Array[Callable], negations := [0]) -> Array:
	var w = func(k, c, d, n): return c.call(k, d) == n
	var src := dict.keys()
	var i = 0
	var keys := []
	var d := {}
	for c in conditions: keys += src.filter(w.bind(c, dict, negations[++i%negations.size()] == 0))
	for k in keys: d[k] = 1

	return d.keys()

func _filter_and2(dict: Dictionary, conditions: Array[Callable], negations := [0]) -> Array:
	var w = func(k, c, d, n): return c.call(k, d) == n
	var i = 0
	var keys := dict.keys()
	for c in conditions:
		keys = keys.filter(w.bind(c, dict, negations[i] == 0))
		i = (i + 1) % negations.size()

	return keys

func _filter_and(values, conditions: Array[Callable], negations := [0]) -> Array:
	return _filter(false, values, conditions, negations)

func _filter_or(values, conditions: Array[Callable], negations := [0]) -> Array:
	return _filter(true, values, conditions, negations)

func _filter(is_or: bool, values, conditions: Array[Callable], negations := [0]) -> Array:
	negations = negations.map(func(v): return v == (0 if is_or else 1))
	var array: Array = values if typeof(values) == TYPE_ARRAY else values.values()

	return array.filter(func(value):
		var nidx := 0
		for condition: Callable in conditions:
			if condition.call(value) == negations[nidx]:
				return is_or
			nidx = (nidx + 1) % negations.size()
		return not is_or
	)

#endregion Filtering
