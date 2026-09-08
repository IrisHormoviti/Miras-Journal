extends CanvasLayer
signal response
var value: int = 0
var active := false


func _ready() -> void:
	hide()


func ask_for_confirm(text: String, label: String = "WARNING", awnser: Array[String] = ["No", "Yes"], color: Color = Color.hex(0xdc000eff)) -> int:
	var t := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property($Bg, "modulate", Color(1, 1, 1, 0.8), 0.5).from(Color.TRANSPARENT)
	t.tween_property($Panel, "scale:y", 1, 0.3).from(0)
	show()
	for i in $Panel/Options.get_children():
		i.hide()
	for i in awnser.size():
		if awnser[i] != "":
			$Panel/Options.get_child(i).show()
			$Panel/Options.get_child(i).text = awnser[i]
	$Panel/Label.text = text
	$Panel/Label2.text = label
	$Panel/Options/No.grab_focus()
	await t.finished
	active = true
	await response
	active = false
	print("awnser: " + str(value))
	t = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property($Bg, "modulate", Color.TRANSPARENT, 0.1)
	t.tween_property($Panel, "modulate", Color.TRANSPARENT, 0.1)
	t.tween_property($Panel, "scale:y", 0, 0.1)
	await t.finished
	queue_free()
	return value


func _on_no_pressed() -> void:
	if not active: return
	Audio.cancel_sound()
	value = 0
	response.emit()


func _on_yes_pressed() -> void:
	if not active: return
	Audio.confirm_sound()
	value = 1
	response.emit()


func _on_maybe_pressed() -> void:
	if not active: return
	Audio.confirm_sound()
	value = 2
	response.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("ui_cancel"):
		_on_no_pressed()
	get_viewport().set_input_as_handled()
	if is_instance_valid(Global.player) and Global.controllable: _on_no_pressed()
