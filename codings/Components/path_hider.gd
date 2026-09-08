extends Area2D

var t: Tween


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	show()
	modulate = Color.WHITE
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	for i in get_children(): show()


func _on_body_entered(body: Node2D) -> void:
	if body == Global.player:
		if is_instance_valid(t): t.kill()
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		use_parent_material = false
		t = create_tween()
		t.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)


func _on_body_exited(body: Node2D) -> void:
	if body == Global.player:
		if is_instance_valid(t): t.kill()
		t = create_tween()
		t.tween_property(self, "modulate", Color.WHITE, 0.5)
		await t.finished
		if modulate == Color.WHITE:
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			use_parent_material = true
