@tool
extends EditorPlugin

const AUTOLOAD_NAME = "Utils"

func _enable_plugin():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/utils/utils.tscn")

func _disable_plugin():
	remove_autoload_singleton(AUTOLOAD_NAME)
