extends CanvasLayer

@export var DiaryEntries: Dictionary
var stage: String
var current_pages: Array[String]
var page_index: int = 0
var page_day: int = 0
@onready var page_indicator: PanelContainer = $PageIndicator


func _ready() -> void:
	$Close.icon = Global.get_controller().CancelIcon
	$Select.icon = Global.get_controller().ConfirmIcon
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
	page_indicator.hide()
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
	load_entries()
	stage = "diary"
	$Journal.hide()
	$RootMenu.hide()
	$JournalBack.show()
	$Pages.show()
	$List.show()
	$Select.hide()
	page_indicator.show()
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
	var text: String = Query.get_month_name(Query.get_month(day)) + " " + Query.get_date_day(day) + "\n\n"
	for i in Event.Diary[day]:
		text += DiaryEntries.get(i)
		#text += "\n~~~~~~\n"

	if page_day > day:
		current_pages = split_by_pages(text)
	await handle_page_turning(page_day, day, page_index, current_pages.size())
	current_pages = split_by_pages(text)
	page_day = day

	%TextL.text = ""
	%TextR.text = ""
	page_index = 0
	display_text(current_pages)


func handle_page_turning(old_day: int, new_day: int, old_index: int, old_day_page_count: int) -> void:
	print("---- turning page from %d to %d" % [old_day, new_day])
	if new_day == old_day: return
	var going_right: bool = new_day > old_day
	var L: int = min(new_day, old_day)
	var R: int = max(new_day, old_day)

	for i in range(L, R):
		if Event.Diary.has(i):
			prints("day i", i)
			if i == L and old_day_page_count > 1:
				for j in range(old_index / 2, old_day_page_count / 2):
					prints("	j", j)
					if going_right: turn_page_R()
					else: turn_page_L()
					await Event.wait(0.1, false)
			else:
				print("	single page")

				if going_right: turn_page_R()
				else: turn_page_L()
				if i != new_day:
					await Event.wait(0.1, false)


func split_by_pages(text: String) -> Array[String]:
	text = insert_images(text)
	const page_line_count := 18
	var split_by_line := text.split('\n')
	var result: Array[String]
	var page_count: int = ceil(float(split_by_line.size()) / float(page_line_count))
	page_count += text.count("[/img]")
	page_count += text.count("[page]")
	var line: int = 0
	for i in page_count:
		result.append("")
		for j in page_line_count:
			if line >= split_by_line.size():
				break
			elif "[page]" in split_by_line[line]:
				line += 1
				break
			else:
				result[i] += split_by_line[line] + "\n"
				line += 1
				if "/img" in split_by_line[line - 1]:
					break
	while result.back().is_empty() and not result.is_empty():
		result.erase(result.back())
	return result


func display_text(text: Array[String] = current_pages, left_page: int = page_index) -> void:
	var pageL: int = left_page
	var pageR: int = left_page + 1
	if current_pages.size() > pageL:
		%TextL.text = current_pages[pageL]
		if current_pages.size() > pageR:
			%TextR.text = current_pages[pageR]
	elif page_index > 0:
		display_text(current_pages, left_page - 1)
	%PageIndex.text = "%d/%d" % [ceil(page_index / 2) + 1, max(ceil(current_pages.size() / 2), 1)]


func turn_page_R() -> void:
	const time := 0.3
	var L: TextureRect = $Pages/PageL.duplicate()
	var R: TextureRect = $Pages/PageR.duplicate()
	$Pages.add_child(R)
	$Pages.add_child(L)
	R.z_index = 5
	L.z_index = 2

	var t := create_tween()
	t.tween_property(R, ^"scale:x", 0, time / 2).from(1)
	await Event.wait(time / 2, false)

	var L_new: TextureRect = $Pages/PageL.duplicate()
	$Pages.add_child(L_new)
	L_new.z_index = 5
	t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(L_new, ^"scale:x", 1, time / 2).from(0)

	await t.finished
	L.queue_free()
	L_new.queue_free()
	R.queue_free()


func turn_page_L() -> void:
	const time := 0.3
	var L: TextureRect = $Pages/PageL.duplicate()
	var R: TextureRect = $Pages/PageR.duplicate()
	$Pages.add_child(R)
	$Pages.add_child(L)
	R.z_index = 2
	L.z_index = 5

	var t := create_tween()
	t.tween_property(L, ^"scale:x", 0, time / 2).from(1)
	await Event.wait(time / 2, false)

	var R_new: TextureRect = $Pages/PageR.duplicate()
	$Pages.add_child(R_new)
	R_new.z_index = 5
	t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(R_new, ^"scale:x", 1, time / 2).from(0)

	await t.finished
	L.queue_free()
	R.queue_free()
	R_new.queue_free()


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


func insert_images(text: String) -> String:
	text = text.replace("[diary_doodle]", "[img width=420]res://art/Journal/DiaryDoodles/")
	return text


func _input(_event: InputEvent) -> void:
	$Close.icon = Global.get_controller().CancelIcon
	$Select.icon = Global.get_controller().ConfirmIcon

	if stage == "diary":
		if Input.is_action_just_pressed("ui_right"):
			if page_index + 2 >= current_pages.size():
				var foc := get_viewport().gui_get_focus_owner()
				foc.find_next_valid_focus().grab_focus()
			else:
				page_index += 2
				turn_page_R()
				display_text()
		if Input.is_action_just_pressed("ui_left"):
			if page_index - 2 < 0:
				var foc := get_viewport().gui_get_focus_owner()
				foc.find_prev_valid_focus().grab_focus()
			else:
				page_index -= 2
				turn_page_L()
				display_text()


func load_entries() -> void:
	DiaryEntries = YAMLParser.load_yaml_file("res://database/Text/Journal/Diary.yaml")
	print(DiaryEntries)


func diary_focus_button() -> void:
	var foc := get_viewport().gui_get_focus_owner()
	diary_focus(int(foc.name))
