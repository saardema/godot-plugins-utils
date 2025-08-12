# @tool
class_name ToggleLabelList
extends Control

signal was_toggled(label: ToggleLabel)

const toggle_label_scene = preload("toggle_label.tscn")

enum Mode {Single = 1, SingleOrNone, Multi}
const SINGLE_MODES := Mode.Single | Mode.SingleOrNone

var mode: Mode = Mode.Single
var labels: Dictionary[StringName, ToggleLabel]
var selected_label: ToggleLabel
var selected_labels: Dictionary[StringName, ToggleLabel]
var child_list: ToggleLabelList
var prior_selections: Dictionary[StringName, StringName]
var outer_hash: StringName
var global_hash: StringName
var _clear_on_ready: bool
var selected_meta: Variant:
	get: return selected_label.meta if selected_label else null

var selected_meta_list: Array[Variant]:
	get: return selected_labels.values().map(func(label): return label.meta)


func _ready():
	if _clear_on_ready:
		for child in get_children():
			child.queue_free()


func create_label(text: String, meta: Variant = null) -> ToggleLabel:
	var label: ToggleLabel = toggle_label_scene.instantiate()
	add_child(label)
	label.text = text
	if meta != null: label.meta = meta
	label.clicked.connect(_on_label_clicked)
	labels[label.id] = label

	if mode == Mode.Single and labels.size() == 1:
		selected_label = label
		label.is_toggled = true

	return label


func find(meta: Variant) -> ToggleLabel:
	for label in labels.values():
		if label.meta == meta: return label
	return null


func update_hash(new_outer_hash: StringName = &''):
	if new_outer_hash != &'':
		outer_hash = new_outer_hash

	if selected_label:
		global_hash = outer_hash + '_' + selected_label.id
		if child_list:
			child_list.update_hash(global_hash)


func select(meta: Variant, emit := true, save := false):
	set_selection(find(meta), emit, save)


func set_selection(label: ToggleLabel, emit := true, save := false):
	if selected_label is ToggleLabel:
		selected_label.is_toggled = false

	if label is ToggleLabel:
		label.is_toggled = mode == Mode.Single or not label.is_toggled
	elif mode == Mode.Single:
		label = get_prior_selection()
		if label == null: label = labels.values()[0]
		label.is_toggled = true

	selected_label = label
	update_hash()

	if save: save_selection()
	if emit: was_toggled.emit(label)


func add_to_multi_selection(label: ToggleLabel, emit := true):
	label.is_toggled = true
	selected_labels[label.id] = label
	if emit: was_toggled.emit(label)

func remove_from_multi_selection(label: ToggleLabel, emit := true):
	label.is_toggled = false
	selected_labels.erase(label.id)
	if emit: was_toggled.emit(label)


func _on_label_clicked(label: ToggleLabel):
	# Single-selection mode
	if mode == Mode.Single:
		set_selection(label)
	elif mode == Mode.SingleOrNone:
		set_selection(label if not label.is_toggled else null)

	# Multi-selection mode
	elif label.is_toggled:
		remove_from_multi_selection(label)
	else:
		add_to_multi_selection(label)

	save_selection()

	# print('\n'.join(prior_selections.keys().map(func(k):
	# 	return "%s: %s" % [k, prior_selections[k]]
	# )))
	# print('---')


func save_selection():
	if selected_label:
		prior_selections[outer_hash] = selected_label.id
	else:
		prior_selections.erase(outer_hash)


func get_prior_selection() -> ToggleLabel:
	var selection = prior_selections.get(outer_hash)
	return labels.get(selection) if selection else null


func restore_selection():
	set_selection(get_prior_selection())


func destroy_label(label: ToggleLabel):
	if label.id in labels:
		labels.erase(label.id)
	label.queue_free()


func clear_labels():
	for label in labels.values():
		destroy_label(label)
	labels.clear()


func set_child_list(child: ToggleLabelList):
	child_list = child
