@tool
extends EditorProperty

const STEP_LIST_SCENE = preload("res://addons/battle_step_editor/action_sequence_content.tscn")

var list


func _init() -> void:
	list = STEP_LIST_SCENE.instantiate()
	list.set_title("")
	add_child(list)
	set_bottom_editor(list)
	draw_background = false
	list.steps_changed.connect(on_steps_changed)


func _update_property() -> void:
	if list == null:
		return

	list.setup(get_edited_object(), get_edited_property())


func on_steps_changed(property: StringName, steps: Array) -> void:
	emit_changed(property, steps)
