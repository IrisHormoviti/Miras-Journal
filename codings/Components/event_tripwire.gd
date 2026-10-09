@tool
@icon("res://art/Icons/Editor/event_tripwire.png")
class_name EventTripwire
extends Area2D

@export var trigger_size := Vector2i(50, 50):
	set(x):
		trigger_size = x
		var coll: CollisionShape2D = get_node_or_null("CollisionShape2D")

		if coll != null:
			coll.shape = coll.shape.duplicate()
			coll.shape.size = x
@export_category("Flags")
## Flag expression in order for this event to trigger
@export_multiline() var flag: String
## What should the flag expression equal to in order for this event to trigger?
@export var flag_should_be: bool
## The name of the node will be used as the flag in addition to the specified flag
@export var use_name_as_flag: bool = true
## If FlagIsname is on, it will be added as the flag regardless of what is set in the flag
@export var add_the_flag: bool = false
@export_category("Player Control")
## When this event is triggered, the player won't have control
@export var take_control: bool = true
## Return control after the event has finished
@export var return_control: bool = true
@export_category("Result")
@export_group("Show Textbox")
## Play dialogue when the event is triggered
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var ShowTextbox := false
## How the dialogue is played
@export_enum("Textbox", "Passive", "Headless") var textbox_mode: String = "Textbox"
@export_enum("testbush") var text_file: String
## The ~title in the dialogue to show
@export_enum("start") var text_cue: String
@export_group("Start Battle")
## When entering this tripwire, start a battle immediatly
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var StartBattle := false
@export var battle_sequence: BattleSequence
@export_group("Pop Tutorial")
## Show a tutorial popup
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var PopTutorial := false
@export var tutorial_name: String
@export_group("Alter Movment")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var AlterMovement := false
## While the event lasts, the player walks slower
@export var slow_down: bool = false
## Move the player to a specific direction when the event is triggered
@export var kick_direction: Direction


func _validate_property(property: Dictionary) -> void:
	if not Engine.is_editor_hint():
		return

	match property.name:
		"text_file":
			var files := DirAccess.get_files_at("res://database/Text/")
			var files_filtered: Array[String]
			for i in files:
				if not i.ends_with(".import"):
					files_filtered.append(i.replace(".dialogue", ""))

			property.hint_string = ",".join(files_filtered)

		"text_cue":
			if text_file == "": return
			var text_res: DialogueResource = load("res://database/Text/"+text_file+".dialogue")

			if text_res:
				property.hint_string = ",".join(text_res.get_cues())


func kick() -> void:
	print("kick!")
	Global.player.look_to(kick_direction)
	while Global.player in get_overlapping_bodies():
		await Global.player.move_dir(kick_direction)


func get_name_flag() -> String:
	return Global.room.codename() + "/Tripwire/" + name


func condition() -> bool:
	if not flag.is_empty():
		if Event.f(flag) != flag_should_be:
			return false

	if Event.check_flag(get_name_flag()):
		return false

	return true


func _on_body_entered(body: Node2D) -> void:
	if not body is Mira: return

	if condition():
		print("Tripwire: ", name)

		if use_name_as_flag:
			Event.add_flag(get_name_flag())

		if add_the_flag:
			if not flag.is_empty():
				Event.add_flag(flag)

		if slow_down:
			await Event.take_control()
			Event.give_control(true)
			Global.player.can_dash = false
			Global.player.speed = 50

		if not tutorial_name.is_empty():
			Event.pop_tutorial(tutorial_name)

		if take_control:
			await Event.take_control(false, true, true)

		if kick_direction:
			kick()

		if text_file != "":
			match textbox_mode:
				"Passive":
					await Passive.open(text_file, text_cue)
				"Headless":
					await Event.run_cue(text_file, text_cue)
				_:
					await Textbox.open(text_file, text_cue)

		if battle_sequence != null:
			Battle.start(battle_sequence)

		if slow_down:
			Global.player.speed = Global.player.WALK_SPEED
			Global.player.can_dash = true

		if return_control:
			Event.give_control(true)
