extends CanvasLayer


func _ready() -> void:
	var file := FileAccess.open("res://credits.txt", FileAccess.READ)
	$Text.text = file.get_as_text() if file else ""
	var t := create_tween()
	t.tween_property($Text, "position:y", -$Text.size.y, 25).from(1000)
	await t.finished
	await Event.wait(3)
	UI.title_screen()
	queue_free()
