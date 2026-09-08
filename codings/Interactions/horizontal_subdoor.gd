extends Area2D

@export var LeftSubarea: SubRoom = null
@export var RightSubarea: SubRoom = null
var busy := false


func _on_body_exited(body: Node2D) -> void:
	if body == Global.player and not busy:
		busy = true
		if body.position.x > position.x:
			await Event.take_control(true, true)
			Global.player.collision(false)
			if RightSubarea != null: RightSubarea.transition()
			LeftSubarea.fade_out()
			#await Global.Player.go_to(Vector2(global_position.x + 4, Global.Player.position.y), false, false, Vector2.RIGHT, 4)
			#if to_local(Global.Player.position).x < 0 or Global.Player in get_overlapping_bodies():
				#Global.Player.position.x = global_position.x + 24
			Event.give_control(false)
		elif body.position.x < position.x:
			await Event.take_control(true, true)
			Global.player.collision(false)
			if LeftSubarea != null: LeftSubarea.transition()
			RightSubarea.fade_out()
			#await Global.Player.go_to(Vector2(global_position.x - 4, Global.Player.position.y), false, false, Vector2.LEFT, 4)
			#if to_local(Global.Player.position).x > 0 or Global.Player in get_overlapping_bodies():
				#Global.Player.position.x = global_position.x - 24
			Event.give_control(false)
		busy = false
