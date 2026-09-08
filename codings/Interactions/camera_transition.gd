extends Area2D

@export var ToCam1 = 0
@export var ToCam2 = 0
@export var updown = false


func _on_body_entered(body: Node2D) -> void:
	if body == Global.player and Global.room.current_subroom == null:
		await Event.take_control(true, true)
		var dir: Vector2
		if updown:
			if to_local(Global.player.position).y > 0:
				dir = Vector2.DOWN
				Global.room.index = ToCam2
			else:
				dir = Vector2.UP
				Global.room.index = ToCam1
		else:
			if to_local(Global.player.position).x > 0:
				dir = Vector2.RIGHT
				Global.room.index = ToCam2
			else:
				dir = Vector2.LEFT
				Global.room.index = ToCam1
		await Global.player.go_to(global_position + dir * 12, false, true, Vector2.UP, 24)
		Event.give_control(false)

#func _on_body_exited(body: Node2D) -> void:
	#if body == Global.Player and to_local(Global.Player.position).y > 0 and Global.Area.CurSubRoom == ToSubarea:
		#await Event.take_control(true, true)
		#if ToSubarea != null: ToSubarea.detransition()
		#await Global.Player.go_to(global_position + Vector2(0, 12), false, true, Vector2.DOWN, 12)
		#Event.give_control(false)
		#if to_local(Global.Player.position).y < 0 or Global.Player in get_overlapping_bodies() or $"../SubRoomBg".modulate == Color.WHITE:
			#Global.Player.position.y = global_position.y + 24
			#Global.refresh()
