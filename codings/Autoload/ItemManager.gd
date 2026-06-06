extends Control
@export var KeyInv: Array[ItemData]
@export var ConInv: Array[ItemData]
@export var MatInv: Array[ItemData]
@export var BtiInv: Array[ItemData]
var item: ItemData
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
	Global.item_sound()
	if pickup_anim: pickup.emit()
	label.text = named
	Dicon.texture = icon
	await get_tree().create_timer(0.1).timeout
	var panel_size := label.get_theme_font("font").get_string_size(named, 0, -1, 32).x + 70
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	panel.size.x = 69
	await Event.wait()
	var player_pos: Vector2 = Global.Player.get_global_transform_with_canvas().origin - Vector2(48, 0)
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
	Global.check_party.emit()
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
	Global.check_party.emit()
	await t.finished
	panel.hide()


func add_item(ItemName: Variant, type: StringName = &"", animate := true, player_animate := true, quantity := -1) -> void:
	if ItemName is String and ItemName == "":
		Global.toast("You got absolutely nothing!!!")
		return
	item = get_item(ItemName, type).duplicate()
	if type == &"": type = item.ItemType
	if item == null:
		OS.alert("THERE'S NO ITEM CALLED " + ItemName, "OOPS")
		return
	var inv: Array[ItemData] = get_inv(type)
	var amount := item.AmountOnAdd if quantity == -1 else quantity
	if not check_item(ItemName, type):
		item.Quantity = amount
		inv.append(item)
	else: for i in inv:
		if i.filename == item.filename:
			i.Quantity += amount
	overwrite_inv(inv, type)
	print("Added item ", item.Name, " of type ", type)
	if animate: get_animation(item.Icon, item.Name, player_animate)


func remove_item(ItemName: Variant, type: StringName = &"") -> void:
	item = get_item(ItemName, type)
	if type == &"": type = find_type(item)
	if item == null:
		OS.alert("THERE'S NO ITEM CALLED " + ItemName, "OOPS")
	var inv: Array[ItemData] = get_inv(type)
	item.Quantity -= 1
	print("Item ", item.Name, " removed")
	if item.Quantity <= 0:
		item.Quantity = 0
		inv.erase(item)
	overwrite_inv(inv, type)


func check_item(ItemName: Variant, type: StringName = &"") -> bool:
	item = get_item(ItemName, type)
	if item == null: OS.alert("THERE'S NO ITEM CALLED " + ItemName, "OOPS")
	if item in get_inv(type): return true
	else: return false


func get_inv(type: String) -> Array[ItemData]:
	type = type.capitalize()
	match type:
		&"Key": return KeyInv
		&"Con": return ConInv
		&"Mat": return MatInv
		&"Bti": return BtiInv
		_:
			push_error("Invalid inventory " + type)
			return []


func overwrite_inv(inv: Array, type: StringName) -> void:
	type = type.capitalize()
	match type:
		&"Key": KeyInv = inv
		&"Con": ConInv = inv
		&"Mat": MatInv = inv
		&"Bti": BtiInv = inv


func get_folder(type: StringName) -> String:
	match type:
		&"Key": return "KeyItems"
		&"Con": return "Consumables"
		&"Mat": return "Materials"
		&"Bti": return "BattleItems"
		_: return ""


func use(iteme: ItemData) -> void:
	item = iteme
	$ItemEffect.use(iteme)


func get_item(iteme: Variant, type: StringName = &"") -> ItemData:
	var ritem: Variant = null  #???? this feels wrong.
	if type == &"": type = find_type(iteme)
	if iteme is String:
		for i in get_inv(type):
			if iteme == i.filename:
				ritem = i
		if ritem == null:
			ritem = load("res://database/Items/" + get_folder(type) + "/" + iteme + ".tres")
			if ritem == null:
				OS.alert("Invalid item ", iteme)
				return null
			ritem.filename = iteme
	elif iteme is ItemData:
		find_filename(iteme)
		if iteme.filename == "Invalid filename":
			OS.alert(iteme.filename)
		for i in get_inv(type):
			if iteme.filename == i.filename:
				ritem = i
		if ritem == null:
			ritem = load("res://database/Items/" + get_folder(type) + "/" + iteme.filename + ".tres")
			ritem.filename = iteme.filename
	else: OS.alert("That's not a valid item name")
	return ritem


func find_filename(iteme: ItemData, type: String = "") -> void:
	iteme.filename = iteme.Name.to_pascal_case()
	#if type == "": type = find_type(iteme)
	#for file in DirAccess.get_files_at("res://database/Items/" + get_folder(type)):
		#if ".tres" in file:
			#var ritem:ItemData = await Loader.load_res("res://database/Items/"+get_folder(type)+"/"+ file)
			#if ritem.Name == iteme.Name: iteme.filename = file.erase(file.length()-5, 5)


func verify_inventory() -> void:
	for i in combined_inv():
		if i.filename == "Invalid filename": find_filename(i)
		if i.ItemType == "": i.ItemType = find_type(i)


func find_type(iteme: ItemData) -> StringName:
	if iteme.ItemType != "": return iteme.ItemType
	if iteme in KeyInv:
		return &"Key"
	if iteme in ConInv:
		return &"Con"
	if iteme in MatInv:
		return &"Mat"
	if iteme in BtiInv:
		return &"Bti"
	return &""


func combined_inv() -> Array[ItemData]:
	var rtn := KeyInv.duplicate()
	rtn.append_array(MatInv)
	rtn.append_array(ConInv)
	rtn.append_array(BtiInv)
	#print(rtn)
	return rtn


func save_to_strings() -> Array[String]:
	var rtn: Array[String]
	for aitem in combined_inv():
		for i: int in abs(aitem.Quantity):
			rtn.append(aitem.filename + ":" + find_type(aitem))
	return rtn


func load_inventory(data: Array[String]) -> void:
	KeyInv.clear()
	MatInv.clear()
	BtiInv.clear()
	ConInv.clear()
	for i in data:
		var aitem := i.split(":", false)
		add_item(aitem[0], aitem[1], false, false, 1)
