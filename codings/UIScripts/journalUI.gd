@tool
extends CanvasLayer

signal closed

const orange_color := Color("#e3936e")

@export_tool_button("Next Page", "PageNext") var next_page_btn: Callable = next_page_editor
@export_tool_button("Previous Page", "PagePrevious") var prev_page_btn: Callable = prev_page_editor

@export var diary_entries: Dictionary[String, String]:
	set(value):
		diary_entries = value

		if Engine.is_editor_hint() and is_node_ready():
			save_entries_to_json()
			update_dropdown_list()

@export_enum("Fail") var edit_entry_id: String:
	set(value):
		edit_entry_id = value
		load_entry_for_editor()

@export_multiline var edit_entry_text: String:
	set(value):
		edit_entry_text = value
		update_editor_preview()

@export_tool_button("Save Entry", "Save") var save_btn: Callable = save_entry_for_editor

var entry_dropdown_list: String = ""
var stage: String
var current_pages: Array[String]
var page_index: int = 0
var page_day: int = 0
var entry_enemy: Enemy = null
var battle_entry := false
var battle_tween: Tween
var closing := false
var list_template: Button
var current_beastiary := ""
var beastiary_index := -1
@onready var page_indicator: PanelContainer = $PageIndicator
@onready var text_l: RichTextLabel = %TextL
@onready var text_r: RichTextLabel = %TextR


func _validate_property(property: Dictionary) -> void:
	if property.name == "edit_entry_id":
		property["hint_string"] = entry_dropdown_list


func _ready() -> void:
	if Engine.is_editor_hint():
		load_diary_entries()
		load_entry_for_editor()
		return

	$Close.icon = Controller.get_scheme().CancelIcon
	$Select.icon = Controller.get_scheme().ConfirmIcon
	list_template = $List/List/Listing0

	if entry_enemy != null:
		show_beastiary_entry(entry_enemy)
		return

	diary_load_day_list()
	root()


func update_dropdown_list() -> void:
	var keys: Array = diary_entries.keys()
	var string_keys: Array[String] = []

	for key: Variant in keys:
		string_keys.append(str(key))

	entry_dropdown_list = ",".join(string_keys)
	notify_property_list_changed()


func format_entry_text(text: String) -> String:
	if not text.ends_with('\n'):
		text += '\n'

	return text + "~~~~~~\n"


func load_entry_for_editor() -> void:
	if diary_entries.is_empty():
		load_diary_entries()

	if diary_entries.has(edit_entry_id):
		edit_entry_text = diary_entries[edit_entry_id]

	update_editor_preview()


func update_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return

	$Pages.show()
	current_pages = split_by_pages(format_entry_text(edit_entry_text))
	display_text(current_pages)


func next_page_editor() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return

	if page_index + 2 < current_pages.size():
		page_index += 2
		display_text(current_pages)


func prev_page_editor() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return

	if page_index - 2 >= 0:
		page_index -= 2
		display_text(current_pages)


func save_entries_to_json() -> void:
	var file: FileAccess = FileAccess.open("res://database/Text/Journal/Diary.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(diary_entries, "\t"))
	file.close()


func save_entry_for_editor() -> void:
	diary_entries[edit_entry_id] = edit_entry_text
	save_entries_to_json()
	update_dropdown_list()


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
	var t: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART).set_parallel()
	t.tween_property($Close, "position:x", 200, 0.3)
	t.tween_property($Journal, "position", Vector2(600, 0), 1).from(Vector2(600, 2000))
	t.tween_property($RootMenu, "modulate", Color.WHITE, 0.6).from(Color.TRANSPARENT)
	t.tween_property($RootMenu, "position:x", 254, 0.6).from(400)
	$Select.show()

	if UI.is_open("MainMenu"):
		t.tween_property(UI.get_node("MainMenu"), "offset:x", 0, 0.5)

	if is_instance_valid(Global.camera):
		t.tween_property(Global.camera, "offset:x", 100, 0.5)


func diary() -> void:
	load_diary_entries()
	stage = "diary"
	$Journal.hide()
	$RootMenu.hide()
	$JournalBack.show()
	$Pages.show()
	$List.show()
	$Select.hide()
	page_indicator.show()
	show_diary_pages()
	diary_load_day_list()
	var t: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART).set_parallel()
	t.tween_property($Close, "position:x", 320, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property($List, "position:x", 0, 0.5).from(-300)

	if UI.is_open("MainMenu"):
		t.tween_property(UI.get_node("MainMenu"), "offset:x", -165, 0.5)

	if is_instance_valid(Global.camera):
		t.tween_property(Global.camera, "offset:x", 150, 0.5)

	var first := first_listing()

	if first != null:
		first.grab_focus()


func beastiary() -> void:
	stage = "beastiary"
	current_beastiary = ""
	beastiary_index = -1
	$Journal.hide()
	$RootMenu.hide()
	$JournalBack.show()
	$Pages.show()
	$List.show()
	$Select.hide()
	page_indicator.hide()
	beastiary_load_list()

	var t: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART).set_parallel()
	t.tween_property($Close, "position:x", 320, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property($List, "position:x", 0, 0.5).from(-300)

	if UI.is_open("MainMenu"):
		t.tween_property(UI.get_node("MainMenu"), "offset:x", -165, 0.5)

	if is_instance_valid(Global.camera):
		t.tween_property(Global.camera, "offset:x", 150, 0.5)

	var first := first_listing()

	if first != null:
		first.grab_focus()
	else:
		show_empty_beastiary()


func show_beastiary_entry(enemy: Enemy) -> void:
	if enemy == null:
		return

	stage = "beastiary_entry"
	entry_enemy = enemy
	current_beastiary = str(enemy.codename)
	$Journal.hide()
	$RootMenu.hide()
	$JournalBack.show()
	$Pages.show()
	$List.hide()
	$Select.hide()
	page_indicator.hide()
	$Close.show()
	$Close.position.x = 320
	display_beastiary_entry(enemy)

	if battle_entry:
		center_battle_journal()
		animate_battle_entry_in()

	show()


func center_battle_journal() -> void:
	var half_width: float = get_viewport().get_visible_rect().size.x * 0.5
	var back: TextureRect = $JournalBack
	var shift: float = half_width - (back.position.x + back.size.x * 0.5)
	back.position.x += shift
	$Pages.position.x += shift


func animate_battle_entry_in() -> void:
	var back: TextureRect = $JournalBack
	var pages: Control = $Pages
	var back_target: Vector2 = back.position
	var pages_target: Vector2 = pages.position
	back.position = back_target + Vector2(0, 900)
	pages.position = pages_target + Vector2(0, 900)
	$Fader.modulate = Color(0, 0, 0, 0)
	battle_tween = create_tween()
	battle_tween.set_parallel()
	battle_tween.set_ease(Tween.EASE_OUT)
	battle_tween.set_trans(Tween.TRANS_QUART)
	battle_tween.tween_property(back, "position", back_target, 0.8)
	battle_tween.tween_property(pages, "position", pages_target, 0.8)
	battle_tween.tween_property($Fader, "modulate", Color(0, 0, 0, 0.7), 0.5)
	battle_tween.tween_property($Close, "position", Vector2(31, 742), 0.5).from(Vector2(31, 900))


func animate_battle_entry_out() -> void:
	if is_instance_valid(battle_tween):
		battle_tween.kill()

	var t := create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property($JournalBack, "position", $JournalBack.position + Vector2(0, 900), 0.5)
	t.tween_property($Pages, "position", $Pages.position + Vector2(0, 900), 0.5)
	t.tween_property($Fader, "modulate", Color(0, 0, 0, 0), 0.4)
	await t.finished


func show_empty_beastiary() -> void:
	show_beastiary_pages()
	text_r.text = "No beasts have been recorded yet."
	$Pages/PageL/BeastiarySummary/NameLabel.text = "Beastiary"
	$Pages/PageL/BeastiarySummary/TextureRect.texture = null


func show_diary_pages() -> void:
	$Pages/PageL/TextL.show()
	$Pages/PageL/BeastiarySummary.hide()
	text_r.show()


func show_beastiary_pages() -> void:
	$Pages/PageL/TextL.hide()
	$Pages/PageL/BeastiarySummary.show()
	text_r.show()


func display_beastiary_entry(enemy: Enemy) -> void:
	show_beastiary_pages()
	var summary: Control = $Pages/PageL/BeastiarySummary
	var name_label: Label = summary.get_node("NameLabel")
	var picture: TextureRect = summary.get_node("TextureRect")

	name_label.text = enemy.first_name
	name_label.add_theme_color_override("font_color", enemy.main_color)
	picture.texture = enemy.doodle if enemy.doodle != null else enemy.party_icon

	for entry: Array in [
		["AttackBar", enemy.attack],
		["MagicBar", enemy.magic],
		["DefenceBar", enemy.defence],
	]:
		var bar: ProgressBar = summary.get_node(entry[0])
		bar.max_value = 2
		bar.value = clampf(float(entry[1]), 0, 2)

	var power := enemy.weapon.power if enemy.weapon != null else 0
	summary.get_node("WeaponPower").text = str(power)
	text_r.text = Colorizer.colorize(text_replacement(enemy.description))

	summary.get_node("HealthLabel").text = "Health: %dHP" % enemy.max_hp
	summary.get_node("AuraLabel").text = "Aura: %dAP" % enemy.max_hp
	summary.get_node("HealthLabel").add_theme_color_override("font_color", enemy.main_color)
	summary.get_node("AuraLabel").add_theme_color_override("font_color", enemy.secondary_color)


func load_enemy(codename: String) -> Enemy:
	var path := "res://database/Enemies/%s.tres" % codename

	if not ResourceLoader.exists(path):
		return null

	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Enemy


func first_listing() -> Button:
	for child in $List/List.get_children():
		if child is Button and child != list_template:
			return child

	return null


func clear_list() -> void:
	for child in $List/List.get_children():
		if child == list_template:
			continue

		$List/List.remove_child(child)
		child.queue_free()

	list_template.hide()


func make_listing() -> Button:
	var dub := list_template.duplicate() as Button
	dub.name = "Listing"
	dub.show()
	return dub


func beastiary_load_list() -> void:
	clear_list()

	var entries := Event.beastiary.duplicate()
	entries.reverse()

	for codename: String in entries:
		var enemy := load_enemy(codename)
		var dub := make_listing()
		dub.name = codename
		dub.text = enemy.first_name if enemy != null else codename
		dub.set_meta("EnemyCodename", codename)
		$List/List.add_child(dub)


func beastiary_focus(codename: String) -> void:
	if codename.is_empty() or codename == current_beastiary:
		return

	var new_index := -1

	for child in $List/List.get_children():
		if child is Button and child != list_template and str(child.get_meta("EnemyCodename", "")) == codename:
			new_index = child.get_index()
			break

	var old_index := beastiary_index
	beastiary_index = new_index
	current_beastiary = codename

	if old_index != -1 and new_index != -1 and new_index != old_index:
		if new_index > old_index:
			turn_page_R()
		else:
			turn_page_L()

	var enemy := load_enemy(codename)

	if enemy != null:
		display_beastiary_entry(enemy)


func add_test_entries() -> void:
	Event.diary = {
		2: ["boo"],
		5: ["boo", "bee"]
	}


func diary_load_day_list() -> void:
	clear_list()

	if Event.diary.is_empty(): add_test_entries()

	for i: int in Event.diary:
		var dub := make_listing()
		dub.name = str(i)
		dub.text = "%s %s" % [Query.get_mmm(Query.get_month(i)), Query.get_date_day(i)]
		$List/List.add_child(dub)


func diary_focus(day: int) -> void:
	var text: String = "[b]%s [orange]%s[/orange] [color=#4234216b]%s[/color]\n\n" % [Query.get_month_name(Query.get_month(day)), Query.get_date_day(day), Query.get_year(day)]

	for i: Variant in Event.diary[day]:
		text += format_entry_text(diary_entries.get(i, ""))

	if page_day > day:
		current_pages = split_by_pages(text)

	await handle_page_turning(page_day, day, page_index, current_pages.size())
	current_pages = split_by_pages(text)
	page_day = day

	text_l.text = ""
	text_r.text = ""
	page_index = 0
	display_text(current_pages)


func handle_page_turning(old_day: int, new_day: int, old_index: int, old_day_page_count: int) -> void:
	print("---- turning page from %d to %d" % [old_day, new_day])
	if new_day == old_day: return
	var going_right: bool = new_day > old_day
	var L: int = min(new_day, old_day)
	var R: int = max(new_day, old_day)

	for i: int in range(L, R):
		if Event.diary.has(i):
			prints("day i", i)
			if i == L and old_day_page_count > 1:
				for j: int in range(old_index / 2, old_day_page_count / 2):
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
	const page_line_count: int = 18
	var split_by_line: PackedStringArray = text.split('\n')
	var result: Array[String]
	var page_count: int = ceil(float(split_by_line.size()) / float(page_line_count))
	page_count += text.count("[/img]")
	page_count += text.count("[page]")
	var line: int = 0

	for i: int in page_count:
		result.append("")
		for j: int in page_line_count:
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

	while not result.is_empty() and result.back().is_empty():
		result.pop_back()

	return result


func display_text(text: Array[String] = current_pages, left_page: int = page_index) -> void:
	var pageL: int = left_page
	var pageR: int = left_page + 1

	if text.size() > pageL:
		text_l.text = text_replacement(text[pageL])
	elif page_index > 0:
		display_text(text, left_page - 1)

	if text.size() > pageR:
		text_r.text = text_replacement(text[pageR])
	else: text_r.text = ""

	%PageIndex.text = "%d / %d" % [ceil(page_index / 2) + 1, ceil(current_pages.size() / 2.0)]


func text_replacement(input: String) -> String:
	input = input.replace('{{alcine}}', "Alcine" if Engine.is_editor_hint() else Global.alcine)
	input = input.replace('[orange]', '[color=%s]'%orange_color.to_html())
	input = input.replace('[/orange]', '[/color]')

	return input


func turn_page_R() -> void:
	const time: float = 0.3
	var L: TextureRect = $Pages/PageL.duplicate()
	var R: TextureRect = $Pages/PageR.duplicate()
	$Pages.add_child(R)
	$Pages.add_child(L)
	R.z_index = 5
	L.z_index = 2

	var t: Tween = create_tween()
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
	const time: float = 0.3
	var L: TextureRect = $Pages/PageL.duplicate()
	var R: TextureRect = $Pages/PageR.duplicate()
	$Pages.add_child(R)
	$Pages.add_child(L)
	R.z_index = 2
	L.z_index = 5

	var t: Tween = create_tween()
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
	if closing:
		return

	closing = true

	if battle_entry:
		await animate_battle_entry_out()

	if UI.is_open("MainMenu"):
		UI.get_node("MainMenu")._root()

	closed.emit()
	queue_free()


func _on_back_pressed() -> void:
	Audio.cancel_sound()
	match stage:
		"root":
			close()

		"diary", "beastiary":
			root()

		"beastiary_entry":
			close()


func insert_images(text: String) -> String:
	text = text.replace("[diary_doodle]", "[img width=420]res://art/Journal/DiaryDoodles/")
	return text


func _input(_event: InputEvent) -> void:
	if Engine.is_editor_hint(): return

	$Close.icon = Controller.get_scheme().CancelIcon
	$Select.icon = Controller.get_scheme().ConfirmIcon

	if stage == "diary":
		if Input.is_action_just_pressed("ui_right"):
			if page_index + 2 >= current_pages.size():
				var foc: Control = get_viewport().gui_get_focus_owner()
				foc.find_next_valid_focus().grab_focus()
			else:
				page_index += 2
				turn_page_R()
				display_text()

		if Input.is_action_just_pressed("ui_left"):
			if page_index - 2 < 0:
				var foc: Control = get_viewport().gui_get_focus_owner()
				foc.find_prev_valid_focus().grab_focus()
			else:
				page_index -= 2
				turn_page_L()
				display_text()


func load_diary_entries() -> void:
	if not FileAccess.file_exists("res://database/Text/Journal/Diary.json"):
		return

	var file: FileAccess = FileAccess.open("res://database/Text/Journal/Diary.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())

	if parsed is Dictionary:
		diary_entries.clear()
		for key: Variant in parsed:
			diary_entries[str(key)] = str(parsed[key])

	if Engine.is_editor_hint():
		update_dropdown_list()


func diary_focus_button() -> void:
	var foc: Control = get_viewport().gui_get_focus_owner()

	if stage == "beastiary":
		beastiary_focus(str(foc.get_meta("EnemyCodename", foc.name)))
		return

	diary_focus(int(foc.name))
