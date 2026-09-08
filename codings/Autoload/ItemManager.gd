extends Node

const item_paths: Dictionary[StringName, String] = {
	&"Key": "res://database/Items/KeyItems",
	&"Con": "res://database/Items/Consumables",
	&"Mat": "res://database/Items/Materials",
	&"Bti": "res://database/Items/BattleItems"
}

@export var Inventory: Array[ItemData]
@onready var panel: PanelContainer = $Can/Panel
@onready var obtained: Label = $Can/Panel/HBoxContainer/Label/Obtained
@onready var t: Tween
signal pickup
signal return_member(mem: Actor)
@onready var Dicon: TextureRect = $Can/Panel/HBoxContainer/Icon
@onready var label: Label = $Can/Panel/HBoxContainer/Label
@onready var border: PanelContainer = $Can/Panel/HBoxContainer/Label/Border


func _ready() -> void:
	panel.hide()


func get_animation(icon: Texture2D, named: String, pickup_anim := true) -> void:
	if is_instance_valid(t): t.kill()
	Audio.item_sound()
	if pickup_anim: pickup.emit()
	label.text = named
	Dicon.texture = icon
	await get_tree().create_timer(0.1).timeout
	var panel_size := label.get_theme_font("font").get_string_size(named, 0, -1, 32).x + 70
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	panel.size.x = 69
	await Event.wait()
	var player_pos: Vector2 = Global.player.get_global_transform_with_canvas().origin - Vector2(48, 0)

	if is_instance_valid(t): t.kill()
	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	obtained.self_modulate = Color.TRANSPARENT
	panel.self_modulate = Color.TRANSPARENT
	border.modulate = Color.TRANSPARENT
	t.tween_property(panel, "position", Vector2(620, 250), 0.8).from(player_pos)
	t.tween_property(obtained, "position:x", -100, 0.8).from(-150).set_delay(0.3)
	t.tween_property(obtained, "self_modulate", Color.WHITE, 0.8).from(Color.TRANSPARENT).set_delay(0.4)
	t.tween_property(obtained, "scale", Vector2.ONE, 0.3).from(Vector2(1.5, 1.5)).set_delay(0.4)
	t.tween_property(panel, "modulate", Color.WHITE, 0.5).from(Color.TRANSPARENT)
	t.tween_property(panel, "self_modulate", Color.WHITE, 0.8).from(Color.TRANSPARENT).set_delay(0.2)
	t.tween_property(panel, "position:x", 640 - panel_size / 2, 0.5).set_delay(0.3)
	t.tween_property(panel, "size:x", panel_size, 0.5).set_delay(0.3)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "scale", Vector2.ONE, 0.5).from(Vector2(0.9, 0.9))
	panel.show()
	t.tween_property(border, "modulate", Color.WHITE, 0.5).from(Color.TRANSPARENT).set_delay(0.6)
	t.tween_property(border, "size", Vector2(panel_size + 42, 76), 2).from(Vector2(panel_size + 30, 64)).set_delay(0.6)
	t.tween_property(border, "position", Vector2(-88, -15), 2).from(Vector2(-80, -10)).set_delay(0.6)
	await get_tree().create_timer(3).timeout
	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property(panel, "position", Vector2(54, -100), 0.5).as_relative()
	t.tween_property(panel, "modulate", Color(0, 0, 0, 0), 0.4)
	t.tween_property(panel, "scale", Vector2(0.3, 0.75), 0.5)
	Global.check.emit()
	await t.finished
	panel.hide()


func use_animation(icon: Texture2D, named: String, pos: Vector2) -> void:
	if is_instance_valid(t): t.kill()
	label.text = named
	Dicon.texture = icon
	var panel_size := label.get_theme_font("font").get_string_size(named, 0, -1, 32).x + 70
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	panel.size.x = 69
	await Event.wait()
	if is_instance_valid(t): t.kill()
	panel.show()
	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	obtained.self_modulate = Color.TRANSPARENT
	panel.self_modulate = Color.TRANSPARENT
	border.modulate = Color.TRANSPARENT
	t.tween_property(panel, "position", pos + Vector2(-100, -200), 0.8).from(pos)
	t.tween_property(panel, "modulate", Color.WHITE, 0.5).from(Color.TRANSPARENT)
	t.tween_property(panel, "self_modulate", Color.WHITE, 0.8).from(Color.TRANSPARENT).set_delay(0.2)
	t.tween_property(panel, "position:x", -panel_size / 2, 0.5).set_delay(0.3).as_relative()
	t.tween_property(panel, "size:x", panel_size, 0.5).set_delay(0.3)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "scale", Vector2.ONE, 0.5).from(Vector2(0.9, 0.9))
	await get_tree().create_timer(1).timeout
	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property(panel, "position", Vector2(54, -100), 0.5).as_relative()
	t.tween_property(panel, "modulate", Color(0, 0, 0, 0), 0.4)
	t.tween_property(panel, "scale", Vector2(0.3, 0.75), 0.5)
	Global.check.emit()
	await t.finished
	panel.hide()


func add_item(item_input: Variant, type: StringName = &"", animate := true, player_animate := true) -> void:
	var to_add: ItemData

	if item_input is String:
		if item_input.is_empty():
			Global.toast("You got absolutely nothing!!!")
			return
		else:
			to_add = await get_item(item_input, type)
	elif item_input is ItemData:
		to_add = item_input

	if to_add == null:
		Global.error("THERE'S NO ITEM CALLED " + item_input, "OOPS")
		return

	Inventory.append(to_add)

	if animate:
		print_rich("[color=cyan]Added item ", to_add.Name, " of type ", to_add.ItemType)
		get_animation(to_add.Icon, to_add.Name, player_animate)


func remove_item(item_input: Variant, type: StringName = &"") -> void:
	var to_remove: ItemData
	if item_input is String:
		to_remove = await get_item(item_input, type)
	elif item_input is ItemData:
		to_remove = item_input

	if type == &"": type = to_remove.ItemType
	if to_remove == null:
		Global.error("THERE'S NO ITEM CALLED " + item_input, "OOPS")

	print_rich("[color=cyan]Item ", to_remove.Name, " removed")

	Inventory.erase(to_remove)


func check_item(input: Variant) -> bool:
	if input is String:
		return Inventory.find_custom(func(x: ItemData) -> bool:
			return x.filename == input
		) != -1
	elif input is ItemData:
		return Inventory.has(input)
	else:
		return false


func get_inv(type: String) -> Array[ItemData]:
	type = type.capitalize()
	return Inventory.filter(func(x: ItemData) -> bool:
		return x.ItemType == type
	)


func use(iteme: ItemData) -> void:
	$ItemEffect.use(iteme)


func find_filename(iteme: ItemData, type: String = "") -> void:
	if iteme.filename.is_empty():
		iteme.filename = iteme.Name.to_pascal_case()


func verify_inventory() -> void:
	for i in Inventory:
		if i.filename == "Invalid filename": find_filename(i)


func get_item(filename: String, item_type: StringName = &"") -> ItemData:
	var path: String = ""

	if item_type.is_empty():
		for folder: String in item_paths.values():
			path = folder.path_join(filename)+".tres"

			if ResourceLoader.exists(path):
				continue
	else:
		path = item_paths.get(item_type).path_join(filename)+".tres"

	if path.is_empty():
		Global.error("Invalid item: ", filename)
		return null

	var loaded_item: ItemData = await Loader.load_res(path)

	if loaded_item == null:
		push_warning("Failed to load item: ", filename)
		return null

	loaded_item.resource_name = loaded_item.Name
	return loaded_item


func save_to_strings() -> Array[String]:
	var rtn: Array[String]
	for aitem in Inventory:
		rtn.append(aitem.filename + ":" + aitem.ItemType)

	return rtn


func load_inventory(data: Array[String]) -> void:
	Inventory.clear()
	print_rich("[color=cyan]Inventory: ", data)

	for i in data:
		var aitem := i.split(":", false)
		add_item(aitem[0], aitem[1], false, false)


func count(item_data: ItemData) -> int:
	return Inventory.count(item_data)
