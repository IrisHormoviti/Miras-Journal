@tool
extends RefCounted
class_name StepEditor


static func only(property: Dictionary, visible: Array[String]) -> void:
	if not Engine.is_editor_hint():
		return

	if property.usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
		return

	var property_name := str(property.name)
	if property_name == "script" or property_name.begins_with("resource_"):
		return
	if property_name in visible:
		property.usage |= PROPERTY_USAGE_EDITOR
	else:
		property.usage &= ~PROPERTY_USAGE_EDITOR
