extends Control

@export var bt: Battle


func _process(_delta: float) -> void:
	var screen_pos: Vector2 = bt.act.get_global_transform_with_canvas().origin
	position = screen_pos
	scale = bt.cam.zoom
