class_name MenuSystem

enum ItemType {Action, Toggle}
var menus: Dictionary[PopupMenu, Dictionary]
var _last_index: int = -1


func add_toggle_item(menu: PopupMenu, title: String, is_toggled: bool = false, callback = null, property_base = null, property: StringName = &""):
	var item: Dictionary[String, Variant] = {
		"title": title,
		"is_toggled": is_toggled,
		"callback": callback,
		"property_base": property_base,
		"property": property
	}
	_create_item(menu, item, ItemType.Toggle)


func add_action_item(menu: PopupMenu, title: String, action_name: String):
	var item: Dictionary[String, Variant] = {
		"title": title,
		"action_name": action_name
	}
	_create_item(menu, item, ItemType.Action)


func _create_item(menu: PopupMenu, item: Dictionary, type := ItemType.Toggle):
	if not menus.has(menu): menus[menu] = {'items': {}}

	item['index'] = _generate_index()
	item['slug'] = get_slug(item)
	item['type'] = type

	menus[menu].items[item['index']] = item


func build():
	for menu in menus:
		for item in menus[menu].items.values():
			if item.type == ItemType.Action:
				menu.add_item(item.title, item.index, item.action_name)
			elif item.type == ItemType.Toggle:
				menu.add_check_item(item.title, item.index, item.is_toggled)
		menu.index_pressed.connect(_on_index_pressed.bind(menu))


func _on_index_pressed(index: int, menu: PopupMenu):
	var item: Dictionary = menus[menu].items[index]
	if item.type == ItemType.Toggle:
		item.is_toggled = not item.is_toggled
		menu.set_item_checked(index, item.is_toggled)
		if item.callback is Callable:
			item.callback.call(item.is_toggled)
		if item.property_base != null and item.property != null:
			item.property_base.set(item.property, item.is_toggled)


func _generate_index() -> int:
	_last_index += 1
	return _last_index


func get_slug(item: Dictionary) -> String:
	return item.title.to_snake_case()
