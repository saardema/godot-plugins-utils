@tool
extends ToggleLabelList

const ToggleLabelList = preload("toggle_label_list.gd")

var plotter: Plotter
var feature_to_label_map: Dictionary[Plotter.Feature, ToggleLabel] = {}


func init(plotter_node: Plotter):
	plotter = plotter_node
	plotter.draw_mode_changed.connect(build_list)
	build_list()

func build_list():
	clear_labels()
	feature_to_label_map.clear()

	var features := plotter.draw_mode_features[plotter.draw_mode]
	for feature in features:
		var enabled := feature_to_label_map.size() == 0
		var text := str(Plotter.Feature.keys()[feature])
		var label: ToggleLabel = create_label(feature, text, enabled)
		feature_to_label_map[feature] = label
