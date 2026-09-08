extends Node2D

@export var offset := Vector2.ZERO


func _ready() -> void:
	reparent.call_deferred(Global.camera, false)
	position = offset
