@tool
@icon("res://art/Icons/Editor/door.png")
extends Node2D
class_name Gate
## A gate that opens when its flag is set, with an optional linked [Interactable]
## (a switch) that opens it through the camera-focus animation.
##
## Different from [OpenDoor], which moves the player into a subroom: a gate only
## blocks or unblocks a path. Its open/closed state is stored in a flag so it
## survives loading a save.
##
## A [Sprite] ([AnimatedSprite2D]) child with a "default" and a "hide" animation
## is expected, matching what [HideOnFlag] uses on the old door nodes. This node
## is meant to be a child of the blocking [StaticBody2D]; the parent's collision
## shapes are toggled along with the animation.

## The switch that opens this gate. When set, interacting with it opens the gate
## and it hides itself. Leave empty for a gate opened only by dialogue.
@export var interactable: Interactable
## Expression that decides whether the gate is open, evaluated with [method
## Event.f]. Supports compound expressions like [code]"WitheredLeaves/A+WitheredLeaves/B"[/code].
## Leave empty to derive it from the room and node name ([code]<Room>/Gate/<name>[/code]).
@export var condition: String
## Skip the camera focus on the gate before opening it.
@export var skip_camera := false
## Seconds the camera lingers on the gate while it opens.
@export var focus_time := 3.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite")

var busy := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if condition.is_empty():
		condition = get_name_flag()

	if interactable != null:
		interactable.action.connect(open)
		if interactable.hide_on_flag.is_empty():
			interactable.hide_on_flag = get_name_flag()

	Global.check.connect(update)
	update()


## The fallback flag used when [member condition] is empty and as the linked
## interactable's hide/write flag.
func get_name_flag() -> String:
	return Global.room.codename() + "/Gate/" + name


## Whether the gate should currently be open.
func is_open() -> bool:
	return Event.f(condition)


## Play the gate open (or closed) animation and toggle the parent's collision.
func update() -> void:
	var open := is_open()
	var body := get_parent()

	if sprite != null:
		if open:
			if sprite.animation != "hide": sprite.play("hide")
		else:
			if sprite.animation != "default": sprite.play("default")

	if body is CollisionObject2D:
		for i in body.get_children():
			if i is CollisionShape2D:
				i.set_deferred("disabled", open)


## Open the gate: focus the camera on the parent, play the animation, and store
## the state in the flag.
func open() -> void:
	if busy or is_open():
		return

	busy = true
	var body := get_parent()

	if not skip_camera:
		Event.take_control()
		Global.player.camera_follow(false)
		Global.camera.position = body.global_position if body is Node2D else global_position

		await Event.wait(1)

	# A linked switch writes its own flag (its hide_on_flag); on its own, the
	# gate stores its name flag.
	if interactable != null:
		Event.add_flag(interactable.hide_on_flag, true)
	else:
		Event.add_flag(get_name_flag(), true)
	update()

	if not skip_camera:
		Global.check.emit()
		await Event.wait(focus_time, false)
		Event.give_control(true)

	if interactable != null:
		interactable.check()

	busy = false
