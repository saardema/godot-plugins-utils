@tool
class_name ConnectionsState
extends Resource

signal loaded
signal hydrated

const BASE_PATH: String = "plotter_state"
const EXTENSION: String = "tres"

var identifier: String
var save_path: String:
	get: return '%s_%s.%s' % [BASE_PATH, identifier, EXTENSION]
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

func save(rate_limited := true):
	# DebugTools.print('Save triggered')
	if rate_limited: save_rate_limiter.exec()
	else: _save()


func _save():
	active_instance.serialize()
	print(active_instance.state)


	if identifier.is_empty():
		identifier = resource_scene_unique_id

	resource_path = save_path

	if ResourceSaver.save(active_instance, save_path) == OK:
		DebugTools.print('Saved: %s' % save_path)
	else:
		DebugTools.print('Failed to save connections state')


func load_instance():
	loading_is_attempted = true
	var new_instance := ResourceLoader.load(save_path, 'StateInstance')
	if new_instance is StateInstance:
		active_instance = new_instance


func hydrate(channels: Dictionary[StringName, Plotter.Channel]):
	if not loading_is_attempted: load_instance()

	active_instance.deserialize(channels)
	hydrated.emit(active_instance)
	DebugTools.print('Hydrated connections state with %d connections' % active_instance.connections.size())
