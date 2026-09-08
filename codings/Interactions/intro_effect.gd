extends CanvasLayer

var ref: Node2D


func _ready() -> void:
	hide()


func animate() -> void:
	show()
	$Sprite.play("Hit")
	#var t := create_tween().set_ease(Tween.EASE_OUT)
	#t.tween_property($Sprite, "rotation_degrees", 15, 1).from(0)
	await Event.wait(3)
	queue_free()


func _on_sprite_frame_changed() -> void:
	if ref != null: $Sprite.position = ref.position
