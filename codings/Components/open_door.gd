@icon("res://art/Icons/Editor/door.png")
extends Area2D
class_name OpenDoor

@export var ToSubarea: SubRoom = null


func _on_body_entered(body: Node2D) -> void:
	if body == Global.player and Global.room.current_subroom == null:
		if ToSubarea != null: ToSubarea.transition()
		await Global.player.stop_dash()
		Global.player.local_controllable = false
		await Global.player.go_to(global_position + Vector2(0, -12), false, true, Vector2.UP, 24)
		Global.player.local_controllable = true


func _on_body_exited(body: Node2D) -> void:
	if body == Global.player and to_local(Global.player.position).y > 0 and Global.room.current_subroom == ToSubarea:
		await Global.player.stop_dash()
		Global.player.local_controllable = false
		if ToSubarea != null: ToSubarea.detransition()
		await Global.player.go_to(global_position + Vector2(0, 12), false, true, Vector2.DOWN, 12)
		Global.player.local_controllable = true
		#if to_local(Global.Player.position).y < 0 or Global.Player in get_overlapping_bodies() or $"../SubRoomBg".modulate == Color.WHITE:
			#Global.Player.position.y = global_position.y + 24
			#Global.refresh()
