@tool
extends BattleStep
class_name DialogueStep

@export var file := "":
	set(value):
		if file == value:
			return

		file = value
		notify_property_list_changed()
@export var cue := ""
@export var passive := false
@export var wait := true


func run(_ctx: ActionSequenceContext) -> void:
	if passive:
		if wait:
			Battle.push_modal_dialogue()
			await Passive.open(str(file), str(cue))
			Battle.pop_modal_dialogue()
		else:
			Passive.open(str(file), str(cue))
	else:
		if wait:
			Battle.push_modal_dialogue()
			await Textbox.open(str(file), str(cue))
			Battle.pop_modal_dialogue()
		else:
			Textbox.open(str(file), str(cue))


func _to_string() -> String:
	var parts := PackedStringArray(["Passive" if passive else "Dialogue"])

	if not str(file).is_empty():
		parts.append(str(file))

	if not str(cue).is_empty():
		parts.append(str(cue))

	return " ".join(parts)


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"file":
			StepEditor.dialogue_files(property)
		&"cue":
			StepEditor.dialogue_cues(property, file)


func _icon() -> String:
	return "Script"
