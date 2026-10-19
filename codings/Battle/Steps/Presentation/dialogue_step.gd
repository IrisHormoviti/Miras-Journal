@tool
extends BattleStep
class_name DialogueStep

@export var file: StringName = &""
@export var cue: StringName = &""
@export var passive := false
@export var wait := true


func run(_ctx: ActionSequenceContext) -> void:
	if passive:
		if wait:
			await Passive.open(str(file), str(cue))
		else:
			Passive.open(str(file), str(cue))
	else:
		if wait:
			await Textbox.open(str(file), str(cue))
		else:
			Textbox.open(str(file), str(cue))


func _to_string() -> String:
	var parts := PackedStringArray(["Passive" if passive else "Dialogue"])

	if not str(file).is_empty():
		parts.append(str(file))

	if not str(cue).is_empty():
		parts.append(str(cue))

	return " ".join(parts)


func _icon() -> String:
	return "Script"
