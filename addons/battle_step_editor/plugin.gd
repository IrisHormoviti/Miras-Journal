@tool
extends EditorPlugin

const StepArrayInspectorPlugin = preload("res://addons/battle_step_editor/step_array_inspector_plugin.gd")

var _inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	_inspector_plugin = StepArrayInspectorPlugin.new()
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	if _inspector_plugin == null:
		return

	remove_inspector_plugin(_inspector_plugin)
	_inspector_plugin = null
