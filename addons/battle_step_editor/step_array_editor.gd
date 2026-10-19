@tool
extends EditorProperty

const StepListScene = preload("res://addons/battle_step_editor/step_array_content.tscn")

var _list


func _init() -> void:
	_list = StepListScene.instantiate()
	_list.set_title("")
	add_child(_list)
	set_bottom_editor(_list)
	draw_background = false
	_list.steps_changed.connect(_on_steps_changed)


func _update_property() -> void:
	if _list == null:
		return

	_list.setup(get_edited_object(), get_edited_property())


func _on_steps_changed(property: StringName, steps: Array) -> void:
	emit_changed(property, steps)
