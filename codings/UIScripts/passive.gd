extends CanvasLayer
class_name Passive

var portrait_img: Texture
var has_portrait := false
var redraw_portrait_next_time := true
static var current: Passive = null:
	get():
		if current == null:
			for i: Node in Engine.get_main_loop().root.get_children():
				if i is Passive:
					current = i
					return i

			return null

		if not is_instance_valid(current):
			return null

		return current
static var is_open := false


static func open(file: String, cue: String = "0", extra_game_states: Array = []) -> void:
	print_rich("[color=orange]Passive: ", file, " - ", cue)

	if Engine.get_main_loop().root.has_node("Passive"):
		Engine.get_main_loop().root.get_node("Passive")._on_close()
		await Event.wait(0.3)
		open(file, cue, extra_game_states)
		return

	is_open = true
	var passive: PackedScene = await Loader.load_res("res://UI/Textbox/Passive.tscn")
	var box: Node = passive.instantiate()
	Engine.get_main_loop().root.add_child(box)
	box.start(
		await Loader.load_res("res://database/Text/" + file + ".dialogue") as DialogueResource,
		cue,
		extra_game_states
	)
	await Event.passive_close
	is_open = false

@onready var balloon: ColorRect = $Balloon
@onready var character_label: Label = null
@onready var dialogue_label := $Balloon/Panel2/DialogueLabel
@onready var responses_menu: VBoxContainer = null
@onready var response_template: Button = null
@onready var Portrait: TextureRect = $Balloon/Margin/Portrait
var currun := false
@onready var t: Tween
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

		if not next_dialogue_line:
			_on_close()
			return

		dialogue_line = next_dialogue_line

		var char_name := tr(dialogue_line.character, "dialogue")

		if dialogue_line.text == "(hide)" or dialogue_line.text == " ":
			await hide_box()
			next(dialogue_line.next_id)
			char_name = ""
			return

		var split := char_name.split(".")
		char_name = split[0]

		if split.size() > 1:
			var redraw: bool = true

			if prev_char == char_name: redraw = false
			portrait(char_name+split[1], redraw)

		prev_char = char_name

		var bord1: StyleBoxFlat = $Balloon/Panel2/Border1.get_theme_stylebox("panel")
		var mem := await BoxProfile.match_profile(char_name)
		bord1.border_color = mem.Bord1
		$Balloon/Panel2/Border1.add_theme_stylebox_override("panel", bord1.duplicate())
		var bord2: StyleBoxFlat = $Balloon/Panel2/Border1/Border2.get_theme_stylebox("panel")
		bord2.border_color = mem.Bord2
		$Balloon/Panel2/Border1/Border2.add_theme_stylebox_override("panel", bord2.duplicate())
		var bord3: StyleBoxFlat = $Balloon/Panel2/Border1/Border2/Border3.get_theme_stylebox("panel")
		bord3.border_color = mem.Bord3
		$Balloon/Panel2/Border1/Border2/Border3.add_theme_stylebox_override("panel", bord3.duplicate())
		var inner: StyleBoxFlat = $Balloon/Panel2.get_theme_stylebox("panel")
		inner.bg_color = mem.Inner
		$Balloon/Panel2/DialogueLabel.add_theme_color_override("default_color", mem.TextColor)
		dialogue_line.text = dialogue_line.text.replace("/*", "[color=Gray]*")
		dialogue_line.text = dialogue_line.text.replace("*/", "*[/color]")

		dialogue_label.modulate.a = 0
		#dialogue_label.custom_minimum_size.x = dialogue_label.get_parent().size.x - 1
		dialogue_label.dialogue_line = dialogue_line

		# Show any responses we have
		#responses_menu.modulate.a = 0
		#await t.finished
		if dialogue_line.responses.size() > 0:
			t = create_tween()
			t.set_parallel(true)
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_QUAD)
			for response: DialogueResponse in dialogue_line.responses:
				# Duplicate the template so we can grab the fonts, sizing, etc
				var item: Button = response_template.duplicate(0)
				item.name = "Response%d" % responses_menu.get_child_count()

				if not response.is_allowed:
					item.name = String(item.name) + "Disallowed"
					item.modulate.a = 0.4

				item.text = response.text
				item.show()

				responses_menu.add_child(item)
				t.tween_property(responses_menu, "position", Vector2(832, 318), 1).from(Vector2(2000, 318))

		# Show our balloon
		draw_portrait()
		dialogue_label.text = ""

		if not balloon.visible:
			balloon.show()
			t = create_tween()
			t.set_parallel(true)
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_BACK)
			t.tween_property($Balloon, "modulate", Color(1, 1, 1, 1), 0.3).from(Color(0, 0, 0, 0))
			t.tween_property($Balloon, "scale", Vector2(1, 1), 0.3).from(Vector2(0.7, 0.2))
#		else:
#			t.tween_property($Balloon, "scale", Vector2(1,1), 0.2).from(Vector2(0.9,0.9))

		will_hide_balloon = false

		dialogue_label.modulate.a = 1
		#await get_tree().create_timer(0.2).timeout
		if not dialogue_line.text.is_empty():
			var prof := await BoxProfile.match_profile(char_name)
			dialogue_label.type_out_with_sound(prof.TextSound, prof.AudioFrequency, prof.PitchVariance)
			await dialogue_label.finished_typing

		if dialogue_line.time != "":
			var time := dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
			await get_tree().create_timer(time).timeout
			next(dialogue_line.next_id)
		else:
			var time := dialogue_line.text.length() * 0.02 + 1
			await get_tree().create_timer(max(time, 2)).timeout
			next(dialogue_line.next_id)

	get:
		return dialogue_line


func _ready() -> void:
	#	response_template.hide()

	Portrait.hide()
	balloon.hide()
	balloon.custom_minimum_size.x = balloon.get_viewport_rect().size.x

	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)
	#Engine.get_singleton("DialogueManager").close.connect(_on_close)


## Start some dialogue
func start(dialogue_resource: DialogueResource, title: String, extra_game_states: Array = []) -> void:
	#Global.Controllable = false
	temporary_game_states = extra_game_states
	is_waiting_for_input = false
	resource = dialogue_resource
	#Hud.UIvisible = false
	#await get_tree().create_timer(0.3).timeout
	if resource == null:
		queue_free()
		return

	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)


## Go to the next line
func next(next_id: String) -> void:
	self.dialogue_line = await resource.get_next_dialogue_line(next_id, temporary_game_states)

### Signals


func _on_close() -> void:
	await hide_box()
	Event.passive_close.emit()
	if self != null: queue_free()


func hide_box() -> void:
	t = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(Portrait, "modulate", Color(0, 0, 0, 0), 0.2)
	t.tween_property(balloon, "modulate", Color(0, 0, 0, 0), 0.2)
	t.tween_property(balloon, "scale", Vector2(0.9, 0.5), 0.2)
	await t.finished
	Portrait.hide()
	balloon.hide()


func _on_mutated(_mutation: Dictionary) -> void:
	is_waiting_for_input = false
	will_hide_balloon = true
	get_tree().create_timer(0.1).timeout.connect(
		func() -> void:
			if will_hide_balloon:
				will_hide_balloon = false
	)


func draw_portrait() -> void:
	#await get_tree().create_timer(0.2).timeout
	if has_portrait:
		Portrait.texture = portrait_img
		portrait_clear()
		Portrait.show()
		if redraw_portrait_next_time:
			t = create_tween()
			t.set_parallel(true)
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_CUBIC)
			t.tween_property(Portrait, "modulate", Color(1, 1, 1, 1), 0.3).from(Color(0, 0, 0, 0))
			#t.tween_property(Portrait, "position", Vector2(-55, 389), 0.3).from(Vector2(-200, 389))
	else:
		if Portrait.visible:
			t = create_tween()
			t.set_parallel(true)
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_CUBIC)
			t.tween_property(Portrait, "modulate", Color(0, 0, 0, 0), 0.2)
			#t.tween_property(Portrait, "position", Vector2(-200, 389), 0.3)
			await get_tree().create_timer(0.2).timeout

		Portrait.hide()


func portrait_clear() -> void:
	has_portrait = false


func set_next_box(profile: String) -> void:
	current.next_box = profile


func set_picture(img: String) -> void:
	current.picture = await Loader.load_res("res://art/Pictures/" + img + ".png")


func picture_clear() -> void:
	current.picture = null


func portrait(img: String, redraw := false) -> void:
	redraw_portrait_next_time = redraw
	has_portrait = true
	portrait_img = await Loader.load_res("res://art/Portraits/" + img + ".png")
