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


## Hides only the named properties, leaving every other property untouched. Use
## this with enable groups, where the group already handles the broad case.
static func hide(property: Dictionary, hidden: Array[String]) -> void:
	if not Engine.is_editor_hint():
		return

	if property.usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
		return

	if str(property.name) in hidden:
		property.usage &= ~PROPERTY_USAGE_EDITOR
