extends Node
var game_exists := false
var inactive := false
var focused := 0

@onready var title_screen: CanvasLayer = $TitleScreen
#unique node names would also be a solution, and makes it less of a pain to write all these vars
@onready var menu_screen: VBoxContainer = $TitleScreen/Menu
@onready var error_screen: Panel = $TitleScreen/Error


func _ready() -> void:
	var error_hint: Label = $TitleScreen/Error/Hint
	#title_screen.hide()
	error_screen.show()
	error_hint.text = "Hint: Ready"
	print("Game Started!")
	glyph_update()
	error_hint.text = "Hint: Glyph"
	Event.add_flag("DisableMenus")
	#Global.controller_changed.connect(glyph_update)
	if FileAccess.file_exists("user://Autosave.tres"):
		game_exists = true
	else:
		game_exists = false
		var continue_button: Button = menu_screen.get_node("Continue")
		continue_button.text = "New game"
	error_hint.text = "Hint: File check"
	title_screen.show()
	var splash_screen: TextureRect = $TitleScreen/Splash
	splash_screen.show()
	var t := create_tween().set_ease(Tween.EASE_IN).set_parallel().set_trans(Tween.TRANS_CUBIC)
	t.tween_property(splash_screen, "modulate", Color.TRANSPARENT, 0.3).from(Color.WHITE).set_delay(0.3)
	#t.tween_property($TitleScreen/Splash, "scale", Vector2(0.6, 0.6), 0.3).set_delay(0.3)
	var version_label: Label = $TitleScreen/Label
	version_label.text += ProjectSettings.get_setting("application/config/version")
	PartyUI.disabled = false
	PartyUI.visible = true
	error_hint.text = "Hint: Should have been fine"
	error_screen.hide()
	if game_exists:
		focus()
	else:
		dismiss_title()
		Event.sequence("new_game")


func focus() -> void:
	menu_screen.get_child(focused).grab_focus()
	get_window().grab_focus()


func _on_continue_pressed() -> void:
	if inactive: return
	inactive = true
	if get_tree().root.has_node("Options"): return
	if Input.is_action_pressed("LeftTrigger"):
		you_can_now_play_as("Asteria")
	await Loader.load_game("Autosave")
	dismiss_title()
	Event.give_control(false)
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	glyph_update()
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down") and get_viewport().gui_get_focus_owner().get_parent() == $TitleScreen/Menu:
		Global.cursor_sound()
		await get_tree().physics_frame
		var foc: Control = get_viewport().gui_get_focus_owner()
		if foc.get_parent() == $TitleScreen/Menu:
			focused = foc.get_index()


func _on_options_pressed() -> void:
	if inactive: return
	if get_tree().root.has_node("Options"): return
	Global.options()
	#dismiss_title()


func dismiss_title() -> void:
	title_screen.hide()
	#Loader.detransition()
	queue_free()


func glyph_update() -> void:
	var options_screen: Button = $TitleScreen/Options
	#options_screen.icon = Global.get_controller().ConfirmIcon
	options_screen.icon = Global.get_controller().Start


func you_can_now_play_as(chara: String) -> void:
	var data: SaveFile = load("user://Autosave.tres")
	if chara in data.Party:
		data.Party[data.Party.find(chara)] = "Mira"
	data.Party[0] = chara
	for i in data.Members:
		if i.get("codename") == chara: i.set("Controllable", true)
	ResourceSaver.save(data, "user://Autosave.tres")
	Global.warning("You can now play as [img height=64]res://art/Icons/Party/" + chara + ".png[/img] " + chara + ".", "CONGRATS", ["A"])


func _on_load_pressed() -> void:
	if inactive: return
	if get_tree().root.has_node("Options"): return
	Global.options(1)


func _on_new_pressed() -> void:
	Global.confirm_sound()
	if not game_exists or await Global.warning("Start a new game? Any Autosave data will be overwritten, so make sure to save it into a new file if you want to keep it.", "NEW GAME", ["Cancel", "Start New Game"]):
		dismiss_title()
		Event.sequence("new_game")
	else:
		focus()
