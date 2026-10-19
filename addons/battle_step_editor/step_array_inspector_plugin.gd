@tool
extends EditorInspectorPlugin

const StepArrayEditor = preload("res://addons/battle_step_editor/step_array_editor.gd")


func _can_handle(object: Object) -> bool:
	return object is Resource


func _parse_property(
	_object: Object,
	type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	_wide: bool,
) -> bool:
	if type != TYPE_ARRAY:
		return false
	if (usage_flags & PROPERTY_USAGE_EDITOR) == 0:
		return false
	if not hint_string.contains("BattleStep"):
		return false

	add_property_editor(name, StepArrayEditor.new())
	return true
