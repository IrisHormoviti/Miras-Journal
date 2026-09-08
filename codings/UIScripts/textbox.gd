extends CanvasLayer
class_name Textbox

static var is_open := false
static var current: Textbox = null:
	get():
		if current == null:
			for i: Node in Engine.get_main_loop().root.get_children():
				if i is Textbox:
					current = i
					return i

			return null

		if not is_instance_valid(current):
			return null

		return current


static func open(file: String, cue: String = "0", fade_bg := false, extra_game_states: Array = []) -> void:
	await kill()
	is_open = true
	print_rich("[color=orange]Textbox: ", file, " - ", cue)
	var Textbox2: PackedScene = await Loader.load_res("res://UI/Textbox/Textbox2.tscn")
	var box: Textbox = Textbox2.instantiate()
	var text: DialogueResource = await Loader.load_res("res://database/Text/" + file + ".dialogue")
	Engine.get_main_loop().root.add_child(box)
	if is_instance_valid(box):
		box.start(text, cue, extra_game_states)

	if fade_bg:
		fade_txt_background()

	Loader.lower_layer()
	await Event.textbox_close
	is_open = false


static func fade_txt_background(alpha := 0.8) -> void:
	if is_instance_valid(current):
		var tw := current.create_tween()
		tw.tween_property(current.get_node("Fader"), "color", Color(0, 0, 0, alpha), 0.5)


static func kill() -> void:
	if is_instance_valid(current):
		current.queue_free()
		await Event.wait()

@onready var balloon: Control = $Balloon
@onready var character_label: Label = %CharacterLabel
@onready var character_panel: PanelContainer = $Balloon/CharacterPanel
@onready var dialogue_label := %DialogueLabel
@onready var responses_menu: VBoxContainer = $Balloon/Responses
@onready var response_template: Button = $Balloon/Responses/Button.duplicate()
@onready var input_indicator: TextureRect = %InputIndicator
@onready var container: PanelContainer = $Balloon/Container
@onready var t: Tween

const hold_time: int = 30
const small_text_size: int = 24
const big_text_size: int = 48

var mem: BoxProfile
var next_box: String = ""
var picture: Texture2D = null
var no_nametag := false
var portrait_img: Texture
var has_portrait := false
var redraw_portrait_next_time := true
var skip := false
var prev_char := ""

## The dialogue resource
var resource: DialogueResource

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

## The current line
var dialogue_line: DialogueLine:
	set(next_dialogue_line):
		is_waiting_for_input = false

		if not is_instance_valid(next_dialogue_line):
			_on_close()
			return

		dialogue_line = next_dialogue_line
		show_dialog_line()


func _ready() -> void:
	response_template.hide()
	$Portrait.hide()
	$Hints.hide()
	balloon.hide()
	balloon.custom_minimum_size.x = balloon.get_viewport_rect().size.x
	has_portrait = false
	portrait_img = null

	if Input.is_action_pressed("Dash"): skip = true

	match Global.settings.TextSpeed:
		1:
			dialogue_label.seconds_per_step = 0.01
			dialogue_label.seconds_per_pause_step = 0.1

		2:
			dialogue_label.seconds_per_step = 0.001
			dialogue_label.seconds_per_pause_step = 0.05

	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)
	#Engine.get_singleton("DialogueManager").dialogue_ended.connect(_on_close)


## Start some dialogue
func start(dialogue_resource: DialogueResource, title: String, extra_game_states: Array = []) -> void:
	Global.controllable = false
	temporary_game_states = extra_game_states
	is_waiting_for_input = false
	resource = dialogue_resource
	#if not Hud.Expanded: Hud.UIvisible = false
	#await get_tree().create_timer(0.3).timeout
	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)

	#for i in get_tree().root.get_children():
		#if i is Textbox and i != self:
			#queue_free()


## Go to the next line
func next(next_id: String) -> void:
	next_box = ""
	self.dialogue_line = await resource.get_next_dialogue_line(next_id, temporary_game_states)


## Draw the textbox, called automatically
func show_dialog_line() -> void:
	var char_name := tr(dialogue_line.character, "dialogue")

	# Remove any previous responses
	for child in responses_menu.get_children():
		responses_menu.remove_child(child)
		child.queue_free()

	if dialogue_line.text == "(hide)" or dialogue_line.text == "[hide]" or dialogue_line.text == "":
		await hide_box()
		next(dialogue_line.next_id)
		redraw_portrait_next_time = true
		char_name = ""
		prev_char = ""
		return

	var splits := dialogue_line.character.split(".")
	char_name = splits[0]

	if splits.size() > 1:
		var redraw: bool = true

		if char_name == prev_char: redraw = false
		portrait(char_name+splits[1], redraw)
	elif portrait_img == null:
		has_portrait = false

	prev_char = char_name

	if not Query.member_exists(char_name):
		character_label.text = char_name
	else: character_label.text = Party.get_member(char_name).FirstName

	input_indicator.hide()
	character_panel.visible = not (character_label.text.is_empty() or no_nametag)
	no_nametag = false
	character_panel.size.x = 1

	if next_box == "": next_box = char_name
	mem = await BoxProfile.match_profile(next_box)

	if "[colorize]" in dialogue_line.text:
		dialogue_line.text = dialogue_line.text.replace("[colorize]", "")
		dialogue_line.text = Colorizer.colorize(dialogue_line.text)

	dialogue_line.text = Query.replace_occurence(dialogue_line.text, "*", "[color=#787878]*", 1)
	dialogue_line.text = Query.replace_occurence(dialogue_line.text, "*", "*[/color]", 2)
	dialogue_line.text = dialogue_line.text.replace("[small]", "[font_size=%d]" % [small_text_size])
	dialogue_line.text = dialogue_line.text.replace("[/small]", "[/font_size]")
	dialogue_line.text = dialogue_line.text.replace("[big]", "[font_size=%d]" % [big_text_size])
	dialogue_line.text = dialogue_line.text.replace("[/big]", "[/font_size]")
	set_colors()
	$PictureFrame/Picture.texture = picture

	dialogue_label.modulate.a = 0
	#dialogue_label.custom_minimum_size.x = dialogue_label.get_parent().size.x - 1
	dialogue_label.dialogue_line = dialogue_line

	# Show any responses we have
	responses_menu.modulate.a = 0
	#await t.finished
	if dialogue_line.responses.size() > 0:
		for response: DialogueResponse in dialogue_line.responses:
			# Duplicate the template so we can grab the fonts, sizing, etc
			var item: Button = response_template.duplicate()
			item.name = "Response%d" % responses_menu.get_child_count()

			if not response.is_allowed:
				item.name = String(item.name) + "Disallowed"
				item.modulate.a = 0.4

			item.text = response.text
			item.show()

			responses_menu.add_child(item)
			item.connect("focus_entered", _on_button_focus_entered)
			item.modulate = Color.TRANSPARENT

		animate_responces()

	# Show our balloon
	draw_portrait()
	dialogue_label.text = ""

	dialogue_label.type_out_with_sound(mem.TextSound, mem.AudioFrequency, mem.PitchVariance)
	await get_tree().process_frame

	var new_size: Vector2 = container.size
	new_size.y = max(dialogue_label.get_minimum_size().y + 18, 100)

	if not balloon.visible and dialogue_line.text != " ":
		balloon.show()
		t = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		t.tween_property(balloon, "modulate", Color(1, 1, 1, 1), 0.4).from(Color(0, 0, 0, 0))
		t.tween_property(balloon, "scale", Vector2(1, 1), 0.4).from(Vector2(0.7, 0.2))
		container.size = new_size
	else:
		t = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(balloon, "scale", Vector2(1, 1), 0.2).from(Vector2(0.95, 0.95))
		t.tween_property(container, "size", new_size, 0.2)

	will_hide_balloon = false

	dialogue_label.modulate.a = 1

	$Balloon/Glow.size = new_size
	$Balloon/Glow2.size = new_size

	await dialogue_label.finished_typing

	# Wait for input
	if dialogue_line.responses.size() > 0:
		responses_menu.modulate.a = 1
		configure_menu()
	elif dialogue_line.time != "":
		var time := dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		input_indicator.show()
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()

### Helpers


func set_colors() -> void:
	var bord1: StyleBoxFlat = %Border1.get_theme_stylebox("panel")
	bord1.border_color = mem.Bord1
	%Border1.add_theme_stylebox_override("panel", bord1.duplicate())
	var bord2: StyleBoxFlat = %Border2.get_theme_stylebox("panel")
	bord2.border_color = mem.Bord2
	%Border2.add_theme_stylebox_override("panel", bord2.duplicate())
	var bord3: StyleBoxFlat = %Border3.get_theme_stylebox("panel")
	bord3.border_color = mem.Bord3
	%Border3.add_theme_stylebox_override("panel", bord3.duplicate())
	var inner: StyleBoxFlat = $Balloon/Container.get_theme_stylebox("panel")
	inner.bg_color = mem.Inner
	var nametag: StyleBoxFlat = character_panel.get_theme_stylebox("panel")
	nametag.bg_color = mem.TextColor
	character_panel.add_theme_stylebox_override("panel", nametag.duplicate())
	character_panel.add_theme_color_override("font_color", mem.Inner)
	input_indicator.modulate = mem.TextColor
	dialogue_label.add_theme_color_override("default_color", mem.TextColor)

	var glow_bord: StyleBoxFlat = $Balloon/Glow.get_theme_stylebox("panel")
	glow_bord.draw_center = true
	glow_bord.bg_color = mem.Bord1 + Color(-0.15, -0.15, -0.15)
	glow_bord.border_color = Color.TRANSPARENT


# Set up keyboard movement and signals for the response menu
func configure_menu() -> void:
	balloon.focus_mode = Control.FOCUS_NONE

	var items := get_responses()

	for i in items.size():
		var item: Control = items[i]

		item.focus_mode = Control.FOCUS_ALL

		item.focus_neighbor_left = item.get_path()
		item.focus_neighbor_right = item.get_path()

		if i == 0:
			item.focus_neighbor_top = item.get_path()
			item.focus_previous = item.get_path()
		else:
			item.focus_neighbor_top = items[i - 1].get_path()
			item.focus_previous = items[i - 1].get_path()

		if i == items.size() - 1:
			item.focus_neighbor_bottom = item.get_path()
			item.focus_next = item.get_path()
		else:
			item.focus_neighbor_bottom = items[i + 1].get_path()
			item.focus_next = items[i + 1].get_path()

		item.mouse_entered.connect(_on_response_mouse_entered.bind(item))
		item.gui_input.connect(_on_response_gui_input.bind(item))

	items[0].grab_focus()
	Audio.stop()


# Get a list of enabled items
func get_responses() -> Array:
	var items: Array = []

	for child in responses_menu.get_children():
		if not "Disallowed" in child.name:
			items.append(child)

	return items

### Signals


func _on_close() -> void:
	Input.action_release("Dash")
	await hide_box()
	$Portrait.hide()
	Engine.time_scale = 1
	responses_menu.hide()
	Event.textbox_close.emit()
	if self != null: queue_free()


func hide_box() -> void:
	if is_instance_valid(t): t.stop()
	t = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(balloon, "modulate", Color(0, 0, 0, 0), 0.2)
	t.tween_property($Fader, "color", Color(0, 0, 0, 0), 0.5)
	t.tween_property(balloon, "scale", Vector2(0.9, 0.5), 0.2)
	if $Portrait.visible:
		while $Portrait.modulate != Color.WHITE and $Portrait.visible:
			await Event.wait()

		t = create_tween()
		t.set_parallel(true)
		t.set_ease(Tween.EASE_IN)
		t.set_trans(Tween.TRANS_CUBIC)
		t.tween_property($Portrait, "modulate", Color(0, 0, 0, 0), 0.3)
		t.tween_property($Portrait, "position:x", -100, 0.3)

	await t.finished
	balloon.hide()
	portrait_img = null
	has_portrait = false
	$Portrait.texture = null
	redraw_portrait_next_time = true
	character_label.text = " "


func _on_mutated(_mutation: Dictionary) -> void:
	is_waiting_for_input = false
	will_hide_balloon = true
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		if will_hide_balloon:
			will_hide_balloon = false)


func _on_response_mouse_entered(item: Control) -> void:
	if "Disallowed" in item.name: return

	item.grab_focus()


func _on_response_gui_input(event: InputEvent, item: Control) -> void:
	if "Disallowed" in item.name:
		return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1:
		next(dialogue_line.responses[item.get_index()].next_id)
		Audio.confirm_sound()
	elif event.is_action_pressed("ui_cancel"):
		responses_menu.get_children().back().grab_focus()
	elif event.is_action_pressed("DialogNext") and item in get_responses():
		Audio.confirm_sound()
		item.release_focus()
		t = create_tween()
		t.set_parallel()
		t.set_trans(Tween.TRANS_QUART)
		t.tween_property(item, "position:x", -100, 0.2).as_relative()
		t.tween_property(item, "modulate", Color.TRANSPARENT, 0.2)
		for i in responses_menu.get_children():
			if item != i:
				t = create_tween()
				t.set_parallel()
				t.set_trans(Tween.TRANS_QUART)
				t.set_ease(Tween.EASE_IN)
				t.tween_property(i, "modulate", Color.TRANSPARENT, 0.2)
				t.tween_property(i, "position:x", 500, 0.2).as_relative()
				await Event.wait(0.05, false)

		await t.finished
		if item == null or item.get_index() == -1: return
		next(dialogue_line.responses[item.get_index()].next_id)


func _input(event: InputEvent) -> void:
	# Typing skip
	if Input.is_action_just_pressed(dialogue_label.skip_action) and dialogue_label.is_typing:
		dialogue_label.visible_ratio = 0.99

	# Fast forward
	if Input.is_action_just_pressed("Dash") or skip:
		skip = false
		var hold_frames := 1
		t = create_tween().set_trans(Tween.TRANS_QUART)
		t.tween_property($Hints, "position:x", 1400, 0.5)
		while Input.is_action_pressed("Dash") and not Global.controllable:
			hold_frames += 1
			await Event.wait()
			Engine.time_scale = 4

			if (
				hold_frames > hold_time and
				dialogue_line.responses.is_empty()
			):
				var action := InputEventAction.new()
				action.action = &"DialogNext"
				action.pressed = true
				Input.parse_input_event(action)
				dialogue_label.visible_ratio = max(0.99, dialogue_label.visible_ratio)

		Engine.time_scale = 1
		return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch:
		next(dialogue_line.next_id)
	elif(event.is_action_pressed("DialogNext")) and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)

	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_pressed() and not event.is_action("DialogNext") and not (
			event.is_action(&"ui_left") or
			event.is_action(&"ui_right") or
			event.is_action(&"ui_up") or
			event.is_action(&"ui_down")
		) and is_waiting_for_input:
			#print(event)
			$Hints/Skip.icon = Controller.get_scheme().Dash
			$Hints/Advance.icon = Controller.get_scheme().ConfirmIcon
			$Hints.show()
			t = create_tween()
			t.set_trans(Tween.TRANS_QUART)
			t.tween_property($Hints, "position:x", 1188, 0.5).from(1400)
			await Event.wait(4, false)
			t = create_tween()
			t.set_trans(Tween.TRANS_QUART)
			t.tween_property($Hints, "position:x", 1400, 0.5)
			await t.finished
			$Hints.hide()


#func _unhandled_input(event: InputEvent) -> void:
	#if not is_waiting_for_input: return
	#if dialogue_line.responses.size() > 0: return
#
	## When there are no response options the balloon itself is the clickable thing
	#get_viewport().set_input_as_handled()


func draw_portrait() -> void:
	#await get_tree().create_timer(0.2).timeout
	if has_portrait:
		if dialogue_line.text.begins_with("[color=") and dialogue_line.text.ends_with("[/color]"):
			$Balloon/Arrow.hide()
		else: $Balloon/Arrow.show()
		var pan: StyleBoxFlat = $Balloon/Arrow.get_theme_stylebox("panel")
		pan.bg_color = mem.Bord1
		$Portrait.texture = portrait_img
		$Portrait/Shadow.texture = $Portrait.texture
		portrait_img = null
		$Portrait.show()
		if redraw_portrait_next_time:
			#if is_instance_valid(t): t.kill()
			t = create_tween()
			t.set_parallel(true)
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_QUINT)
			t.tween_property(balloon, "position:x", 160, 0.5)
			t.tween_property($Portrait, "modulate", Color(1, 1, 1, 1), 0.8).from(Color(0, 0, 0, 0))
			t.tween_property($Portrait, "position:x", 0, 0.8).from(-200)
			t.tween_property($Portrait/Shadow, "position", Vector2(-131, 150), 1).from(Vector2(0, 0))
	else:
		$Balloon/Arrow.hide()
		if $Portrait.visible:
			#if is_instance_valid(t): t.kill()
			t = create_tween()
			t.set_parallel(true)
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_QUAD)
			t.tween_property(balloon, "position:x", 0, 0.5)
			t.tween_property($Portrait/Shadow, "position", Vector2(0, 0), 0.2)
			t.tween_property($Portrait, "modulate", Color(0, 0, 0, 0), 0.3)
			t.tween_property($Portrait, "position:x", -200, 0.3)
			await t.finished

		$Portrait.hide()


func _on_button_focus_entered() -> void:
	Audio.cursor_sound()


func animate_responces() -> void:
	await dialogue_label.finished_typing
	Engine.time_scale = 1

	for i in responses_menu.get_children():
		if "Disallowed" in i.name:
			i.hide()

	for i in responses_menu.get_children():
		if i == null: continue
		t = create_tween()
		t.set_parallel(true)
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(i, "position:x", i.position.x, 0.3).from(500)
		t.tween_property(i, "modulate", Color.WHITE, 0.3).from(Color.TRANSPARENT)
		await Event.wait(0.1, false)


func set_next_box(profile: String) -> void:
	current.next_box = profile


func set_picture(img: String) -> void:
	current.picture = await Loader.load_res("res://art/Pictures/" + img + ".png")


func portrait(img: String, redraw := true) -> void:
	redraw_portrait_next_time = redraw
	has_portrait = true
	portrait_img = await Loader.load_res("res://art/Portraits/" + img + ".png")
