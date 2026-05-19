extends CanvasLayer

@export var DiaryEntries: Dictionary[StringName, String]
var stage: String
var current_pages: Array[String]
var page_index: int = 0


func _ready() -> void:
	$Close.icon = Global.get_controller().CancelIcon
	$Select.icon = Global.get_controller().ConfirmIcon
	load_entries()
	diary_load_day_list()
	root()


func root() -> void:
	stage = "root"
	$Pages.hide()
	$Journal.show()
	$Journal.position = Vector2(600, 0)
	$JournalBack.hide()
	$RootMenu.show()
	$List.hide()
	$RootMenu/Diary.grab_focus()
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART).set_parallel()
	t.tween_property($Close, "position:x", 200, 0.3)
	t.tween_property($Journal, "position", Vector2(600, 0), 1).from(Vector2(600, 2000))
	t.tween_property($RootMenu, "modulate", Color.WHITE, 0.6).from(Color.TRANSPARENT)
	t.tween_property($RootMenu, "position:x", 254, 0.6).from(400)
	$Select.show()
	if get_tree().root.get_node_or_null("MainMenu") != null:
		t.tween_property(get_tree().root.get_node("MainMenu"), "offset:x", 0, 0.5)
		t.tween_property(Global.Camera, "offset:x", 100, 0.5)


func diary() -> void:
	stage = "diary"
	$Journal.hide()
	$RootMenu.hide()
	$JournalBack.show()
	$Pages.show()
	$List.show()
	$Select.hide()
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART).set_parallel()
	t.tween_property($Close, "position:x", 320, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property($List, "position:x", 0, 0.5).from(-300)
	if get_tree().root.get_node_or_null("MainMenu") != null:
		t.tween_property(get_tree().root.get_node("MainMenu"), "offset:x", -165, 0.5)
		t.tween_property(Global.Camera, "offset:x", 150, 0.5)
	$List/List.get_children()[-1].grab_focus()


func add_test_entries() -> void:
	Event.Diary = {
	2: ["boo"],
	5: ["boo", "bee"]
}


func diary_load_day_list() -> void:
	if Event.Diary.is_empty(): add_test_entries()
	for i in Event.Diary:
		var dub: Button = $List/List/Listing0.duplicate()
		dub.name = str(i)
		dub.text = "%s %s" % [Query.get_mmm(Query.get_month(i)), Query.get_date_day(i)]
		$List/List.add_child(dub)
		dub.show()
	$List/List/Listing0.queue_free()


func diary_focus(day: int) -> void:
	%TextL.text = ""
	%TextR.text = ""
	var text: String = Query.get_month_name(Query.get_month(day)) + " " + Query.get_date_day(day) + "\n\n"
	for i in Event.Diary[day]:
		text += DiaryEntries.get(i)
		text += "\n~~~~~~\n"
	current_pages = split_by_pages(text)
	display_text(current_pages)


func split_by_pages(text: String) -> Array[String]:
	const page_line_count := 10
	var split_by_line := text.split('\n')
	var result: Array[String]
	var page_count: int = ceil(float(split_by_line.size()) / float(page_line_count))
	var line: int = 0
	for i in page_count:
		result.append("")
		for j in page_line_count:
			if line <= split_by_line.size():
				break
			else:
				result[i] += split_by_line[line] + "\n"
				line += 1
	return result


func display_text(text: Array[String], left_page: int = page_index) -> void:
	var pageL: int = left_page
	var pageR: int = left_page + 1
	if current_pages.size() > pageL:
		%TextL.text = current_pages[pageL]
	if current_pages.size() > pageR:
		%TextR.text = current_pages[pageR]


func close() -> void:
	if get_tree().root.get_node_or_null("MainMenu") != null:
		get_tree().root.get_node_or_null("MainMenu")._root()
	queue_free()


func _on_back_pressed() -> void:
	Global.cancel_sound()
	match stage:
		"root":
			close()
		"diary":
			root()


func _input(event: InputEvent) -> void:
	$Close.icon = Global.get_controller().CancelIcon
	$Select.icon = Global.get_controller().ConfirmIcon


func load_entries() -> void:
	var file := FileAccess.open("res://database/Text/Journal/Diary.json", FileAccess.READ)
	var json: Array = JSON.parse_string(file.get_as_text())
	for i: Array in json:
		DiaryEntries.set(i[0], i[1])
	print(DiaryEntries)
	file.close()


func diary_focus_button() -> void:
	var foc := get_viewport().gui_get_focus_owner()
	diary_focus(int(foc.name))
