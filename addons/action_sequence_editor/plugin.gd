@tool
extends EditorPlugin

const ActionSequenceInspectorPlugin = preload("res://addons/action_sequence_editor/action_sequence_inspector_plugin.gd")

var inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	inspector_plugin = ActionSequenceInspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)


func _exit_tree() -> void:
	if inspector_plugin == null:
		return

	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null
