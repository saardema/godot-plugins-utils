@tool
extends Container

signal single_selection_changed(selection: Variant)
signal multi_selection_changed(selection: Array[Variant])

const toggle_label_scene = preload("toggle_label.tscn")
const ToggleLabel = preload("toggle_label.gd")
enum SelectionMode {Single, SingleOrNone, Multi}

var selection_mode: SelectionMode = SelectionMode.Single
var label_to_id_map: Dictionary[ToggleLabel, Variant] = {}
var id_to_label_map: Dictionary[Variant, ToggleLabel] = {}
var current_single_selection: Variant:
	set(v):
		if current_single_selection != v:
			current_single_selection = v
			single_selection_changed.emit(v)

var current_multi_selection: Array[Variant]:
	set(v):
		if current_multi_selection != v:
			current_multi_selection = v
			multi_selection_changed.emit(v)


func create_label(
		id: Variant,
		text: String,
		enabled := false,
		use_indicator := false,
		indicator_color := Color.TRANSPARENT
	) -> ToggleLabel:
	var label: ToggleLabel = toggle_label_scene.instantiate()
	add_child(label)
	label_to_id_map[label] = id
	id_to_label_map[id] = label
	label.text = text
	label.use_indicator = use_indicator
	label.indicator_color = indicator_color
	label.before_toggle.connect(_validate_selection.bind(label))
	if enabled: _validate_selection(enabled, label)

	return label


func get_toggled_labels() -> Array[ToggleLabel]:
	return label_to_id_map.keys().filter(func(lbl): return lbl.enabled)


func labels_to_ids(labels: Array[ToggleLabel]) -> Array[Variant]:
	return labels.map(func(lbl): return label_to_id_map[lbl])


func ids_to_labels(ids: Array[Variant]) -> Array[ToggleLabel]:
	return ids.map(func(id): return id_to_label_map[id])


func clear_labels():
	for label in label_to_id_map.keys():
		destroy_label(label)
	label_to_id_map.clear()
	id_to_label_map.clear()


func destroy_label(label: ToggleLabel):
	if label in label_to_id_map:
		id_to_label_map.erase(label_to_id_map[label])
		label_to_id_map.erase(label)
	label.queue_free()


func set_selection_from_ids(ids: Array[Variant]):
	var new_single_selection: Variant
	var new_multi_selection: Array[Variant]

	# Clear current selection
	for label in label_to_id_map.keys():
		label.enabled = false

	# Set new selection
	for id in ids:
		if not id_to_label_map.has(id):
			push_error('ID "%s" not found in list when trying to set new selection' % id)
			return

		var label := id_to_label_map[id]
		label.enabled = true

		if ids.size() == 1:
			new_single_selection = id

		if selection_mode == SelectionMode.Multi:
			new_multi_selection.append(id)

	current_single_selection = new_single_selection
	current_multi_selection = new_multi_selection


func _validate_selection(enabled: bool, label: ToggleLabel):
	if selection_mode != SelectionMode.Multi:
		for lbl in label_to_id_map.keys():
			if lbl == label or not lbl.enabled: continue
			lbl.enabled = false

	if enabled or selection_mode != SelectionMode.Single:
		label.enabled = enabled

	_update_current_selection(label)


func _update_current_selection(label: ToggleLabel):
	if selection_mode == SelectionMode.Multi:
		current_multi_selection = labels_to_ids(get_toggled_labels())
		current_single_selection = null
		if current_multi_selection.size() == 1:
			current_single_selection = current_multi_selection[0]
	else: current_single_selection = label_to_id_map[label] if label.enabled else null
