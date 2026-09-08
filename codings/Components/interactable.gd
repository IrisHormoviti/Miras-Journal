@tool
@icon("res://art/Icons/Editor/Interactable.png")
extends Area2D
class_name Interactable

signal action()

## Size of the trigger to activate the bubble
@export var trigger_size := 12:
	set(x):
		trigger_size = x

		for coll in get_children():
			if coll is CollisionShape2D and coll.shape:
				coll.shape = coll.shape.duplicate()

				if coll.shape is RectangleShape2D:
					coll.shape.size = Vector2(x, x)
				elif coll.shape is CircleShape2D:
					coll.shape.radius = x

## The label shown on the bubble
@export var LabelText: String = "Inspect"
## The mode of the interactable
@export_enum(
	"text",
	"toggle",
	"item",
	"battle",
	"event",
	"pass_time",
	"veinet",
	"focus_cam",
	"social_link",
	"chair",
) var ActionType: String = "text":
	set(x):
		ActionType = x
		setup_action_options()
		notify_property_list_changed()
var Length: int = 120:
	get():
		return(LabelText.length() * 10) + 50
@export_category("Action Options")
@export var file: String = ""
@export_enum("testbush") var dialogue_file: String
@export var title: String = ""
@export_enum("Con", "Mat", "Bti", "Key") var itemtype := "Con":
	set(x):
		itemtype = x
		item = ""
		notify_property_list_changed()
@export_enum("Failed to Load") var item := ""
@export var to_time: Event.TOD
@export var to_time_relative: int
@export var event_condition := ""
@export var chair_faces: Array[String] = ["U", "D", "L", "R"]
@export var return_control := true
@export var focus_position: Vector2
@export_category("Flag")
@export var add_flag: bool = false
@export var show_on_flag: StringName
@export var hide_on_flag: StringName
@export_category("Bubble Options")
@export var bubble_always: bool
@export var Height: int = 0
@export var offset := 5
@export var proper_pos := Vector2.ZERO
@export var proper_face := Vector2.ZERO
@export var needs_bag := false
@export_group("Hiding")
@export var hidesprite: bool = false
@export var hide_parent: bool = false
@export var free_on_hide: bool = false
@export var collision: CollisionShape2D = null
var used_properties: Array[String]
var action_options: Array[String] = [
		"file",
		"title",
		"item",
		"itemtype",
		"to_time",
		"to_time_relative",
		"return_control",
		"event_condition",
		"chair_faces",
		"dialogue_file",
		"focus_position",
	]

@onready var button: Button
@onready var arrow: TextureRect
@onready var dots: TextureRect
@onready var pack := $Pack

var can_interact: bool:
	get():
		can_interact = player_is_near() and Global.controllable and check_flag() and not Battle.in_battle
		return can_interact
var t: Tween
var animating := false


func setup_action_options() -> void:
	if dialogue_file.is_empty(): dialogue_file = file
	match ActionType:
		"text":
			used_properties = ["title", "return_control", "event_condition", "dialogue_file"]

		"toggle":
			used_properties = []
			return_control = true

		"battle":
			used_properties = ["file", "return_control"]

		"event": used_properties = ["event_condition", "file", "return_control"]
		"pass_time": used_properties = ["event_condition", "to_time", "return_control", "to_time_relative"]
		"item":
			used_properties = ["item", "itemtype"]
			return_control = true

		"veinet": used_properties = []
		"social_link":
			used_properties = ["dialogue_file", "return_control", "event_condition"]

		"focus_cam":
			used_properties = ["focus_position"]
			return_control = true

		"chair":
			used_properties = ["chair_faces"]
			return_control = true


## For editor listings
func _validate_property(property: Dictionary) -> void:
	if not Engine.is_editor_hint(): return
	if property.name in action_options:
		if property.name in used_properties:
			property.usage |= PROPERTY_USAGE_EDITOR
		else: property.usage = PROPERTY_USAGE_STORAGE

	match ActionType:
		"text", "social_link":
			if property.name == "dialogue_file":
				var files := DirAccess.get_files_at("res://database/Text/")
				var files_filtered: Array[String]
				for i in files:
					if not i.ends_with(".import"):
						files_filtered.append(i.replace(".dialogue", ""))

				property.hint_string = ",".join(files_filtered)

	if property.name == "item":
		var type: String
		match itemtype:
			"Con": type = "Consumables"
			"Bti": type = "BattleItems"
			"Mat": type = "Materials"
			"Key": type = "KeyItems"

		var files := DirAccess.get_files_at("res://database/Items/" + type)
		var items: Array[String]
		for i in files:
			items.append(i.replace(".tres", ""))

		property.hint_string = ",".join(items)

		if get(property.name) != "" and get(property.name) not in items:
			itemtype = ["Con", "Mat", "Bti", "Key"].pick_random()
			notify_property_list_changed()


func _ready() -> void:
	if Engine.is_editor_hint():
		setup_action_options()
		return

	button = pack.get_node("Cnt/Button")
	arrow = pack.get_node("Arrow")
	dots = pack.get_node("Dots")
	pack.hide()
	button.hide()

	Global.check.connect(check)
	do_position()
	disappear()
	if ActionType == "veinet": vein_check()

	check()


func _exit_tree() -> void:
	pack.queue_free()


func vein_check() -> void:
	if Event.check_flag(get_parent().name):
		get_parent().get_node("Particle").emitting = false
		LabelText = "Enter"
		get_parent().get_node("Sprite").show()
	else:
		get_parent().get_node("Particle").emitting = true
		LabelText = "Open"
		get_parent().get_node("Sprite").hide()

	if Event.check_flag("DisableVeinet"):
		LabelText = "Inspect"


func check() -> void:
	if Engine.is_editor_hint() or Battle.in_battle: return
	if not is_instance_valid(Global.player): queue_free()
	if bubble_always:
		if not Global.controllable: disappear(true)
		else: bubble()
	if Battle.in_battle or not is_instance_valid(Global.player):
		disappear(true)
		return

	if event_condition != "" and Event.condition(event_condition) == 0:
		destroy()

	if not check_flag():
		destroy()

	#print(Global.Controllable, CanInteract)
	if not can_interact:
		disappear()
	elif player_is_near():
		appear()


func check_flag() -> bool:
	if not show_on_flag.is_empty() and not Event.f(show_on_flag):
		return false

	if not hide_on_flag.is_empty() and Event.f(hide_on_flag):
		return false

	return true


func player_is_near() -> bool:
	if not is_instance_valid(Global.player): return false
	return Global.controllable and Global.player.get_node_or_null("DirectionMarker/Finder") in get_overlapping_areas()


func destroy() -> void:
	if hide_parent:
		get_parent().hide()
		get_parent().scale = Vector2.ZERO

		if get_parent() is NPC: get_parent().collision(false)
		if free_on_hide: get_parent().queue_free()
	else:
		if free_on_hide: queue_free()
		hide()
		scale = Vector2.ZERO


func appear() -> void:
	if can_interact and not animating:
		animating = true
		do_position()
		button.text = LabelText
		button.icon = Controller.get_scheme().ConfirmIcon
		z_index = 9

		if is_instance_valid(t): t.kill()
		t = create_tween()
		pack.self_modulate = Color.TRANSPARENT
		dots.hide()
		pack.show()
		button.show()
		arrow.show()
		t.set_parallel(true)
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_BACK)
		t.tween_property(pack, "scale", Vector2(0.4, 0.4), 0.1)
		t.tween_property(dots, "self_modulate", Color(1, 1, 1, 0), 0.1)
		t.tween_property(pack, "self_modulate", Color.WHITE, 0.1).from(Color.TRANSPARENT)
		t.tween_property(button, "custom_minimum_size:x", Length, 0.15).from(48)
		await get_tree().create_timer(0.1).timeout
		animating = false

		if not is_instance_valid(Global.player) or not Global.player.get_node_or_null("DirectionMarker/Finder") in get_overlapping_areas():
			disappear()


func disappear(also_hide_bubble := false) -> void:
	if not animating:
		animating = true

		if bubble_always and not also_hide_bubble:
			await bubble()
		else:
			if is_instance_valid(t): t.kill()
			t = create_tween().set_parallel()
			t.set_ease(Tween.EASE_IN)
			t.set_trans(Tween.TRANS_LINEAR)
			t.tween_property(pack, "self_modulate", Color(1, 1, 1, 0), 0.1)
			t.tween_property(button, "custom_minimum_size:x", 48, 0.1)
			await get_tree().create_timer(0.1).timeout
			pack.hide()
			dots.hide()
			button.hide()

		z_index = 0
		animating = false


func bubble() -> void:
	pack.show()
	button.hide()
	dots.show()
	if is_instance_valid(t): t.kill()
	t = create_tween().set_parallel()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_LINEAR)
	t.tween_property(pack, "scale", Vector2(0.3, 0.3), 0.1)
	t.tween_property(dots, "custom_minimum_size:x", 48, 0.1)
	t.tween_property(pack, "self_modulate", Color(1, 1, 1, 0.2), 0.1)
	t.tween_property(pack.get_node("Dots"), "self_modulate", Color.WHITE, 0.1)
	await get_tree().create_timer(0.2).timeout


#func _input(event: InputEvent) -> void:
	##if Input.is_action_just_pressed("ui_accept"):
		##check()
		##if CanInteract:
			##_on_button_pressed()
#
	#if player_is_near() and not CanInteract:
		#appear()


func do_position() -> void:
	if Battle.in_battle or not is_instance_valid(Global.player):
		pack.hide()
		return

	var cnt: BoxContainer = pack.get_node("Cnt")
	var dir := Direction.snap_vector(to_local(Global.player.position + Vector2(0, Height - offset)))

	if dir == Vector2.UP and bubble_always: dir = Vector2.DOWN
	match dir:
		Vector2.UP:
			cnt.alignment = BoxContainer.ALIGNMENT_CENTER
			cnt.position.x = -180
			pack.position.y = 28 - Height
			pack.position.x = 0
			arrow.flip_h = true
			arrow.position.y = -42

		Vector2.DOWN:
			cnt.alignment = BoxContainer.ALIGNMENT_CENTER
			cnt.position.x = -180
			pack.position.x = 0
			pack.position.y = -10 - Height
			arrow.flip_h = false
			arrow.position.y = -6

		Vector2.LEFT:
			cnt.alignment = BoxContainer.ALIGNMENT_BEGIN
			cnt.position.x = -24
			pack.position.x = 0
			pack.position.y = -10 - Height
			arrow.flip_h = false
			arrow.position.y = -6

		Vector2.RIGHT:
			cnt.alignment = BoxContainer.ALIGNMENT_END
			cnt.position.x = -342
			pack.position.x = 0
			arrow.position.y = -6
			pack.position.y = -10 - Height
			arrow.flip_h = false


func _on_button_pressed() -> void:
	if not can_interact: return

	Global.controllable = false
	Global.player.direction = Vector2.ZERO
	t = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR)
	t.tween_property(pack, "scale", Vector2(0.4, 0.4), 0.1).from(Vector2(0.36, 0.36))
	await Event.wait(0.1, false)
	if needs_bag and not Event.f("HasBag"):
		Global.toast("A bag is needed to store that.")
		Event.give_control()
		return

	if get_tree().root.has_node("Options"):
		get_tree().root.get_node("Options").queue_free()

	if proper_face == Vector2.ZERO:
		Global.player.look_to(Direction.snap_vector(to_local(Global.player.position) * -1))

	if proper_pos != Vector2.ZERO:
		await Event.take_control()
		Global.player.collision(false)
		await Global.player.go_to(proper_pos, false, true, proper_face)

	if get_tree().root.has_node("MainMenu"):
		get_tree().root.get_node("MainMenu").close()

	if not (to_time == 0 and to_time_relative == 0):
		Event.to_time = to_time if to_time_relative == 0 else Event.get_time_progress_from_now(to_time_relative)

	match ActionType:
		"toggle":
			Audio.confirm_sound()

		"text":
			await Event.take_control(false, false, true)
			disappear(true)
			if dialogue_file.is_empty(): dialogue_file = file
			await Textbox.open(dialogue_file, title)

		"item":
			Item.add_item(item, itemtype)

		"battle":
			Battle.start(file)

		"global":
			Global.call(file)

		"event":
			Audio.confirm_sound()
			Event.sequence(file)

		"pass_time":
			if await Hud.confirm_time_passage(title, item):
				Audio.confirm_sound()
				Event.sequence(file)

		"veinet":
			await Event.take_control(false, false, true)
			if Event.check_flag("DisableVeinet"):
				await Textbox.open("interact_abad", "vein_point_idk")
			elif Event.check_flag(get_parent().name):
				Event.veinet_map(get_parent().name.replace("VP", ""))
			else:
				Event.add_flag(get_parent().name, true)
				vein_check()
				disappear()
				await Event.wait(0.3)
				appear()
				Loader.save()

		"focus_cam":
			Event.take_control()
			Global.player.camera_follow(false)
			Global.camera.position = focus_position
			await Event.wait(1)
			if add_flag: Event.add_flag(hide_on_flag, true)
			Global.check.emit()
			await Event.wait(3, false)
			Global.player.camera_follow(true)

		"social_link":
			await Event.take_control(false)
			var rank := Event.condition(event_condition)

			if rank == 0:
				Global.toast("Something went wrong with the event condition")

			disappear(true)
			await Textbox.open(dialogue_file, "rank" + str(rank) + "_prepare")

		"chair":
			await Event.take_control()
			var face := Global.player.facing

			if not chair_faces.is_empty() and not Global.player.facing.get_letter() in chair_faces:
				face = Direction.from_letter(chair_faces[0])

			var pos := Global.player.position
			Global.player.state = NPC.S.NONE
			Global.player.collision(false)
			Global.player.set_anim("Sit" + face.to_string())
			var sound: AudioStreamPlayer2D = get_node_or_null("JumpSound")

			if sound != null:
				sound.pitch_scale = 1
				sound.play()

			await Event.jump_to_global(Global.player, global_position)
			while not Input.is_action_just_pressed(Controller.confirm()):
				await Event.wait()

			if sound != null:
				sound.pitch_scale = 0.8
				sound.play()

			Global.player.look_to(Direction.snap_vector(to_local(pos)))
			await Event.jump_to_global(Global.player, pos)

	if add_flag:
		if hide_on_flag != "":
			Event.add_flag(hide_on_flag, true)
		else: Event.add_flag(name, true)
	if return_control:
		Event.give_control(false)

	if hidesprite:
		if is_instance_valid(collision): collision.set_deferred("disabled", true)
		if hide_parent: get_parent().queue_free()
		else: queue_free()
	action.emit()
	check()


func _on_area_entered(area: Area2D) -> void:
	if not can_interact:
		pack.hide()
		return

	if area == Global.player.get_node_or_null("DirectionMarker/Finder"):
		appear()


func _on_area_exited(area: Area2D) -> void:
	if not is_instance_valid(Global.player): return
	if area == Global.player.get_node_or_null("DirectionMarker/Finder"):
		disappear()
