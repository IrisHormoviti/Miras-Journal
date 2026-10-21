@tool
extends EditorInspectorPlugin

const ACTION_SEQUENCE_EDITOR = preload("res://addons/action_sequence_editor/action_sequence_editor.gd")


func _can_handle(object: Object) -> bool:
	return object is Resource


func _parse_property(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	wide: bool,
) -> bool:
	if type != TYPE_ARRAY:
		return false

	if (usage_flags & PROPERTY_USAGE_EDITOR) == 0:
		return false

	if not hint_string.contains("BattleStep"):
		return false

	add_property_editor(name, ACTION_SEQUENCE_EDITOR.new())
	return true
