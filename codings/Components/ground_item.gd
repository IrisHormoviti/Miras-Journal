@tool
@icon("res://art/Icons/Editor/item.png")
class_name GroundItem
extends Node2D

@export_enum("Con", "Mat", "Bti", "Key") var item_type := "Con":
	set(x):
		item_type = x
		item_name = ""
		notify_property_list_changed()
@export_enum("Failed to Load") var item_name := ""

@onready var interactable: Interactable = $Interactable
@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	name = item_name + str(get_index())
	sprite.frame = randi_range(0, 13)
	interactable.itemtype = item_type
	interactable.item = item_name

	if not Engine.is_editor_hint():
		interactable.hide_on_flag = Global.room.codename() + '/Item/' + name


func _validate_property(property: Dictionary) -> void:
	if property.name == "item_name" and Engine.is_editor_hint():
		var type: String
		match item_type:
			"Con": type = "Consumables"
			"Bti": type = "BattleItems"
			"Mat": type = "Materials"
			"Key": type = "KeyItems"

		var files := DirAccess.get_files_at("res://database/Items/" + type)
		var items: Array[String]
		for i in files:
			items.append(i.replace(".tres", ""))

		property.hint_string = ",".join(items)

		if get(property.name) != "" and get(property.name) not in items:
			item_type = ["Con", "Mat", "Bti", "Key"].pick_random()
			notify_property_list_changed()
