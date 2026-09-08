@tool
@icon("res://art/Icons/Editor/event_tripwire.png")
class_name EventTripwire
extends Area2D

@export var TriggerSize := Vector2i(50, 50):
	set(x):
		TriggerSize = x
		var coll: CollisionShape2D = get_node_or_null("CollisionShape2D")
		if coll != null:
			coll.shape = coll.shape.duplicate()
			coll.shape.size = x
@export_category("Flags")
## Flag expression in order for this event to trigger
@export var Flag: String
## The name of the node will be used as the flag expression if Flag isn't set
@export var FlagIsName: bool = true
## What should the flag expression equal to in order for this event to trigger?
@export var FlagShouldBe: bool
## If FlagIsname is on, it will be added as the flag regardless of what is set in the flag
@export var AddFlag: bool = false
@export_category("Player Control")
## When this event is triggered, the player won't have control
@export var TakeControl: bool = true
## Return control after the event has finished
@export var ReturnControl: bool = true
@export_category("Result")
@export_group("Play Event Sequence")
## Play an event sequence when the event is triggered
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var PlayEvent: bool = false
## Name of the Event sequence
@export var EventName: String
## Waits for the event to finish
@export var AwaitEvent: bool = false
@export_group("Show Textbox")
## Open a textbox when the event is triggered
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var ShowTextbox := false
@export_enum("testbush") var TextFile: String
## The ~title in the dialogue to show
@export var TextNode: String
## Open the passive textbox instead of the normal one
@export var UsePassive: bool = false
@export_group("Start Battle")
## When entering this tripwire, start a battle immediatly
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var StartBattle := false
@export var BattleSeq: BattleSequence
@export_group("Pop Tutorial")
## Show a tutorial popup
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var PopTutorial := false
@export var TutorialName: String
@export_group("Alter Movment")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var AlterMovement := false
## While the event lasts, the player walks slower
@export var SlowDown: bool = false
## Move the player to a specific direction when the event is triggered
@export var KickDirection: Vector2


func _validate_property(property: Dictionary) -> void:
	if not Engine.is_editor_hint():
		return

	match property.name:
		"TextFile":
			var files := DirAccess.get_files_at("res://database/Text/")
			var files_filtered: Array[String]
			for i in files:
				if not i.ends_with(".import"):
					files_filtered.append(i.replace(".dialogue", ""))
			property.hint_string = ",".join(files_filtered)


func kick() -> void:
	print("kick!")
	Global.player.look_to(KickDirection)
	while Global.player in get_overlapping_bodies():
		await Global.player.move_dir(KickDirection)


func _on_body_entered(body: Node2D) -> void:
	if Flag.is_empty() and FlagIsName:
		Flag = name
	if (Event.f(Flag) == FlagShouldBe or Flag == "") and body == Global.player and (not FlagIsName or !Event.check_flag(name)):
		print("Tripwire: ", name)
		if AddFlag:
			if FlagIsName:
				Event.add_flag(name)
			else:
				Event.add_flag(Flag)
		if SlowDown:
			await Event.take_control()
			Event.give_control(true)
			Global.player.can_dash = false
			Global.player.speed = 50

		if not TutorialName.is_empty():
			Event.pop_tutorial(TutorialName)

		if TakeControl:
			await Event.take_control(false, true, true)

		if KickDirection != Vector2.ZERO:
			kick()

		if EventName != "":
			if AwaitEvent:
				await Event.sequence(EventName)
			else:
				Event.sequence(EventName)

		elif TextFile != "":
			if UsePassive:
				await Passive.open(TextFile, TextNode)
			else:
				await Textbox.open(TextFile, TextNode)
		elif BattleSeq != null:
			Battle.start(BattleSeq)
		if SlowDown:
			Global.player.speed = Global.player.WALK_SPEED
			Global.player.can_dash = true
		if ReturnControl:
			Event.give_control(true)
