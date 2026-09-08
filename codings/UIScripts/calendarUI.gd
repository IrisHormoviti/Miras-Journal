extends TextureRect
#@export var HideOnDays: Array[int]
var time_pass_id: String
signal chosen_time_pass(awnser: bool)


func _ready() -> void:
	Global.check.connect(_check_party)
	hide_prompt()


func _check_party() -> void:
	if Event.f("HideDate"):
		$Date/Day.add_theme_font_size_override("font_size", 140)
		$Date/Month.text = "Date"
		$Date/Day.text = "Unknown"
		if not $Action.visible: hide()
	else:
		$Date/Day.add_theme_font_size_override("font_size", 265)
		show()
		$Date/Day.text = Query.get_date_day(Event.day)
		$Date/Month.text = Query.get_month_name(Query.get_month(Event.day))
	$Container/TimeOfDay.text = Query.to_tod_text(Event.time_of_day)
	$Container/TimeOfDay.icon = await Query.to_tod_icon(Event.time_of_day)


func confirm_time_passage(title: String, description: String, to_time: Event.TOD) -> bool:
	Global.check.emit()
	Event.add_flag("DisableMenus", false)
	Global.controllable = false
	get_tree().paused = true
	Hud.show_all()
	Hud.darken()
	var t := create_tween()
	t.set_parallel()
	t.set_trans(Tween.TRANS_QUART)
	$Action.modulate = Color.TRANSPARENT
	t.tween_property($Action, "modulate:a", 1, 0.3)
	t.tween_property($Action, "position:x", -1750, 0.3).from(-1850)
	$Action/RichTextLabel.text = description
	$Action.text = title
	$Future/TimeOfDay.text = Query.to_tod_text(to_time)
	$Future/TimeOfDay.icon = await Query.to_tod_icon(to_time)
	$Action.show()
	$Future.show()
	$Arrow.show()
	show()
	await t.finished
	Global.controllable = false
	$Action/Nevermind.grab_focus()
	return await chosen_time_pass


func hide_prompt() -> void:
	$Action.hide()
	$Future.hide()
	$Arrow.hide()
	await Hud.darken(false)


func _on_nevermind_pressed() -> void:
	Audio.cancel_sound()
	await hide_prompt()
	chosen_time_pass.emit(false)


func use_time() -> void:
	Audio.confirm_sound()
	hide_prompt()
	chosen_time_pass.emit(true)


func _cursor() -> void:
	Audio.cursor_sound()
