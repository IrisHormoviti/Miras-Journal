@tool
@icon("res://art/Icons/Editor/door.png")
class_name Gate
extends StaticBody2D
## A gate that opens when its flag is set, with an optional linked [Interactable]
## (a switch) that opens it.
##
## Not to be confused with [OpenDoor], which moves the player into a subroom.
##
## An [AnimatedSprite2D] child with "default" and "hide" animations is expected,
## matching what [HideOnFlag] uses on the old door nodes. The gate's own collision
## is enabled while shut and disabled while open.

## Size of the collision rectangle
@export var gate_size := Vector2i(55, 21):
	set(x):
		gate_size = x
		update_shape()

## Offset of the collision rectangle from the gate's origin
@export var gate_offset := Vector2(-1, 0):
	set(x):
		gate_offset = x
		update_shape()

## The switch that opens this gate. When set, interacting with it opens the gate
## and it hides itself.
@export var interactable: Interactable
## Expression that decides whether the gate is open.
## Leave empty to derive it from the node name
@export var condition: String
## Skip the camera focus on the gate before opening it
@export var skip_camera := false
## Seconds the camera lingers on the gate while it opens
@export var focus_time := 3.0

@onready var sprite: AnimatedSprite2D = find_sprite()
@onready var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")

var busy := false


func _ready() -> void:
	update_shape()

	if Engine.is_editor_hint():
		return

	if condition.is_empty():
		condition = get_name_flag()

	if interactable != null:
		var linked := interactable
		linked.action.connect(open)
		if linked.hide_on_flag.is_empty():
			linked.hide_on_flag = get_name_flag()

	Global.check.connect(update)
	update()


## Apply [member gate_size] and [member gate_offset] to the collision rectangle
func update_shape() -> void:
	var coll := collision if is_instance_valid(collision) else get_node_or_null("CollisionShape2D")

	if coll == null:
		return

	coll.shape = coll.shape.duplicate() if coll.shape != null else RectangleShape2D.new()

	if coll.shape is RectangleShape2D:
		coll.shape.size = gate_size

	coll.position = gate_offset


## Find the animated sprite to drive, regardless of its node name
func find_sprite() -> AnimatedSprite2D:
	for i in get_children():
		if i is AnimatedSprite2D:
			return i

	return null


func get_name_flag() -> String:
	return Global.room.codename() + "/Gate/" + name


## Whether the gate should currently be open.
func is_open() -> bool:
	return Event.f(condition)


## Play the given animation if the sprite has it.
func play_anim(anim: String) -> void:
	if sprite == null or sprite.animation == anim:
		return

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


## Play the gate open (or closed) animation and toggle the collision.
func update() -> void:
	var is_shut := not is_open()

	play_anim("default" if is_shut else "hide")

	var coll := collision if is_instance_valid(collision) else get_node_or_null("CollisionShape2D")

	if coll != null:
		coll.set_deferred("disabled", not is_shut)


## Open the gate: focus the camera on the gate, play the animation, and store the
## state in the flag.
func open() -> void:
	if busy or is_open():
		return

	busy = true

	if not skip_camera:
		Event.take_control()
		Global.player.camera_follow(false)
		Global.camera.position = global_position

		await Event.wait(1)

	# A linked switch writes its own flag (its hide_on_flag) on its own, the
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
