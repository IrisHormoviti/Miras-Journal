extends Node

@export var ID := ""


func _ready() -> void:
	Event.object_list.set(ID, get_parent())

	DialogueManager.unregister_state_context(ID)
	DialogueManager.register_state_context(ID, get_parent())
