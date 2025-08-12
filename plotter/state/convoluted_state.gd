# # @tool
# class_name ConnectionsState
extends Resource

signal loaded
signal hydrated

const PATH_PREFIX: String = "res://"
const EXTENSION: String = "tres"
var identifier: String = OS.get_unique_id()
var default_save_path: String:
	get: return 'res://plotter_state_%s.%s' % [identifier, EXTENSION]
var save_path: String
var plotter: Plotter
var save_rate_limiter: RateLimiter
@export var active_instance := StateInstance.new()
var loading_is_attempted: bool

var connections: Dictionary[Plotter.Feature, Plotter.Connection]:
	get:
		if active_instance:
			return active_instance.connections
		return {} as Dictionary[Plotter.Feature, Plotter.Connection]


func _init():
	save_rate_limiter = RateLimiter.new(_save, 0.8, RateLimiter.Mode.CONCLUDE)


func set_save_path(state_file_path: String) -> bool:
	if not state_file_path.is_empty() and \
	state_file_path.begins_with(PATH_PREFIX) and \
	state_file_path.ends_with(EXTENSION):
		save_path = state_file_path
		return true

	save_path = default_save_path
	return false


func initialize(state_file_path: String, id: String, plotter_instance: Plotter):
	plotter = plotter_instance
	if plotter.channels.is_empty():
		plotter.channel_added.connect(func(c):
			active_instance.unpack_channel(c)
		)
	else:
		hydrate()

	if identifier.is_empty():
		if resource_scene_unique_id.is_empty():
			generate_scene_unique_id()
		identifier = resource_scene_unique_id
	else: identifier = id

	set_save_path(state_file_path)

	load_instance()

func save(rate_limited := true):
	if rate_limited: save_rate_limiter.exec()
	else: _save()


func _save():
	active_instance.serialize()

	if identifier.is_empty():
		identifier = resource_scene_unique_id

	resource_path = save_path

	if ResourceSaver.save(active_instance, save_path) == OK:
		print('Saved: %s' % save_path)
	else:
		print('Failed to save connections state')


func load_instance():
	loading_is_attempted = true
	print('Loading connections state from: %s' % save_path)
	if not FileAccess.file_exists(save_path):
		FileAccess.open(save_path, FileAccess.WRITE).close()
		print('Created new state file at: %s' % save_path)
		return

	var new_instance := ResourceLoader.load(save_path, 'StateInstance')
	if new_instance is StateInstance:
		active_instance = new_instance
		print('Loaded instance with %d connections' % active_instance.state['connections'].size())


func hydrate():
	if not loading_is_attempted: load_instance()

	active_instance.deserialize(plotter.channels)
	hydrated.emit(active_instance)
	print('Hydrated %d connections' % active_instance.connections.size())
