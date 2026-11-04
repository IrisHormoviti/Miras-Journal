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


## Turns a dialogue file property into a dropdown of the files in database/Text.
static func dialogue_files(property: Dictionary) -> void:
	if not Engine.is_editor_hint():
		return

	var names: Array[String] = []

	for file in DirAccess.get_files_at("res://database/Text/"):
		if file.ends_with(".dialogue"):
			names.append(file.get_basename())

	names.sort()
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(names)


## Turns a dialogue cue property into a dropdown of cues in [param file].
static func dialogue_cues(property: Dictionary, file: String) -> void:
	if not Engine.is_editor_hint():
		return

	var name := file.get_file()

	if name.get_extension() == "dialogue":
		name = name.get_basename()

	var text_res := load("res://database/Text/" + name + ".dialogue") as DialogueResource

	if text_res == null:
		return

	var cues: Array[String] = []

	for cue in text_res.get_cues():
		cues.append(str(cue))

	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(cues)
