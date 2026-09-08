@tool
@icon("res://art/Icons/Editor/transfer.png")
class_name TransferZone
extends Area2D

@export var trigger_size := Vector2i(80, 80):
	set(x):
		trigger_size = x

		for coll in get_children():
			if coll is CollisionShape2D:
				coll.shape = coll.shape.duplicate()
				coll.shape.size = x

@export var _direction: Direction.Ways = Direction.Ways.LEFT
var direction: Direction = null:
	get():
		if direction == null:
			direction = Direction.from_way(_direction)

		return direction

@export var lock_camera := true

@export_category("Transfer To")
@export_enum("Debug") var room: String
@export var subroom: String
@export var ToCamera: int = 0

@export_group("Use Exact Position")
## Use an exact position. Alternatively, specify a subroom
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var UseExactPosition := false
@export var Position := Vector2.ZERO


func _validate_property(property: Dictionary) -> void:
	if not Engine.is_editor_hint(): return

	match property.name:
		"room":
			var files := DirAccess.get_files_at("res://rooms")
			var files_filtered: Array[String]
			for i in files:
				if i.ends_with(".tscn"):
					files_filtered.append(i.replace(".tscn", ""))

			property.hint_string = ",".join(files_filtered)


func _on_entered(body: Node2D) -> void:
	if body == Global.player:
		if Global.controllable or Global.player.dashing or Global.player.attacking:
			proceed()


func come_from() -> Vector2:
	var distance: int
	if direction.is_horizontal():
		distance = trigger_size.x
	else: distance = trigger_size.y
	return position + ((distance) * -direction.vector)


func proceed() -> void:
	var frame := Global.player.sprite.frame
	Global.player.camera_follow(false)
	await Event.take_control(true, true)
	Global.player.collision(false)
	Global.player.move_dir(direction.vector * 48)
	Global.player.sprite.frame = frame
	#print(name, " to ", room, " with camera index ", ToCamera)

	var room_string: String = room

	if not subroom.is_empty():
		room_string += ";" + subroom

	await Loader.travel_to(room_string, Position, ToCamera)


func _on_preview_exited(body: Node2D) -> void:
	if body == Global.player: $Cursor.hide()


func _on_preview_entered(body: Node2D) -> void:
	if body == Global.player: $Cursor.hide()


func _on_body_exited(body: Node2D) -> void:
	if body == Global.player and Direction.from(to_local(body.position)).equals(direction):
		body.position = position - direction.vector * 48
		_on_entered(body)
