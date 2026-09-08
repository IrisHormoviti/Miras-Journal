@tool
@icon("res://art/Icons/Editor/stairs.png")
extends Area2D
class_name Stair

## Set the length of the collision shape
@export_range(10, 300, 1, "prefer_slider") var length: int = 50:
	set(x):
		length = x

		if left_right_mode:
			$CollisionShape2D.shape.size.y = x
		else:
			$CollisionShape2D.shape.size.x = x

## Change to this index when going Down or Left
@export var down_index: CameraIndex
## Change to this index when going Up or Right
@export var up_index: CameraIndex
## Swap left and right
@export var Swap := false
## Left becomes down, Right becomes Up
@export var left_right_mode := false


func _on_body_entered(body: Node2D) -> void:
	print(body.get_class())
	if body is Mira:
		var dir: Vector2 = to_local(body.position) * -1
		go(dir)


func go(dir: Vector2) -> void:
	if Swap: dir *= -1
	if left_right_mode:
		dir.y = 0
		dir = Direction.snap_vector(dir)

		if dir == Vector2.RIGHT:
			go_up()
		elif dir == Vector2.LEFT:
			go_down()
	else:
		dir.x = 0
		dir = Direction.snap_vector(dir)

		if dir == Vector2.UP:
			go_up()
		elif dir == Vector2.DOWN:
			go_down()

	print("entered staircase ", name, " going ", dir)


func _on_body_exited(body: Node2D) -> void:
	if body is Mira:
		var dir: Vector2 = to_local(body.position)
		go(dir)


func go_up() -> void:
	Global.room.change_index(up_index)


func go_down() -> void:
	Global.room.change_index(down_index)
