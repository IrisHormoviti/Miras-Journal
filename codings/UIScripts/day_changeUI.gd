extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await Event.wait(0.5, false)
	Loader.detransition()
	$DayCurrent.text = str(Event.day)
	$Buttons/NextDay.grab_focus()


func _on_next_day_pressed() -> void:
	Audio.confirm_sound()
	$Buttons.hide()
	Event.day += 1
	Event.time_of_day = Event.TOD.MORNING
	$DayCurrent.text = str(Event.day)
	Global.check.emit()
	await Event.wait(2, false)
	Event.next_day.emit()
	queue_free()


func _on_options_pressed() -> void:
	Audio.confirm_sound()
	Global.options()


func _on_quit_pressed() -> void:
	Audio.confirm_sound()
	Global.quit()


func _cursor() -> void:
	Audio.cursor_sound()
