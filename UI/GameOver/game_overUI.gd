extends CanvasLayer
var inactive := true


func _ready() -> void:
	Engine.time_scale = 1
	Loader.battle_result = -1
	Loader.battle_end.emit()
	Battle.in_battle = false
	if is_instance_valid(Global.bt):
		Global.bt.queue_free()
	if is_instance_valid(Global.room):
		Global.room.queue_free()
	Hud.disabled = true
	get_viewport().gui_focus_changed.connect(focus)
	$Options/Retry.grab_focus()
	inactive = false


func retry() -> void:
	if inactive: return
	var t := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	$AnimationPlayer.pause()
	t.tween_property($Options/Load, "modulate:a", 0, 0.3)
	t.tween_property($Options/Quit, "modulate:a", 0, 0.3)
	t.tween_property($BladesOfTime, "rotation_degrees", 0, 0.3)
	await t.finished
	$AnimationPlayer.play("Rewind")
	await Event.wait(0.8)
	await Loader.transition(null)
	await Loader.load_game()
	queue_free()


func _load() -> void:
	if inactive: return
	Global.options(1)
	queue_free()


func _quit() -> void:
	if inactive: return
	Global.quit()


func focus(control):
	if inactive: return
	Audio.cursor_sound()
