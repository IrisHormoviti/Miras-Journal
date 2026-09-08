@tool
@icon("res://art/Icons/Editor/jump.png")
class_name JumpPoint
extends Area2D

const TILE := 24
const Y_ADJUSTMENT := 8

@export var trigger_size := Vector2i(1, 1):
	set(x):
		trigger_size = x
		
		for coll in get_children():
			if coll is CollisionShape2D:
				coll.shape = coll.shape.duplicate()
				coll.shape.size = x * TILE

## Directions where jumping is allowed in
@export var jump_directions: Array[Direction.Ways] = [1, 2, 3, 4]
## Number of tiles to jump
@export var jump_am := 1
@export var jump_am_v := 0
## How long the jump takes
@export_range(0, 10) var time := 5.0
## Vertical leap height during the animation
@export_range(-2, 2) var height := 0.5
## Base the target position on the player's current position, rather than a fixed tile
@export var RelativePositions: bool = false

@export_group("Change layering")
## If not -1, change the player's Z index
@export var to_z: int = -1
## If not 0, change the player's layers
@export_flags_2d_physics var to_layers := 0

var busy: bool = false
var waves: Array[TextureRect]
## 1: Horizontal, 2: Vertical
var dir_mode: int = -1
var is_player_inside: bool = false

@onready var target: TextureRect = $Target
@onready var timer: Timer = $Timer


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	
	if target != null:
		target.hide()

	for i in jump_directions:
		var vector := Direction.way_to_vector(i)
		if dir_mode == -1:
			dir_mode = 2 if vector.x == 0 else 1
		else:
			if (vector.x == 0 and dir_mode == 1) or (vector.y == 0 and dir_mode == 2):
				dir_mode = 0


func _physics_process(_delta: float) -> void:
	if busy or not is_player_inside:
		return
		
	if jump_directions.is_empty():
		Global.toast("No jump dirs here, fix this!")
		return

	var player_face := Global.player.facing.vector
	var local_player_pos := to_local(Global.player.position)
	
	if dir_mode == 1:
		local_player_pos.y = 0
	elif dir_mode == 2:
		local_player_pos.x = 0

	var player_side := Direction.snap_vector(local_player_pos)
	var can_jump := false
	
	for i in jump_directions:
		var dir := Direction.way_to_vector(i)
		if player_face == dir and dir == player_side * -1:
			can_jump = true
	
	if can_jump:
		if not self in Global.player.jump_points:
			Global.player.jump_points.append(self)
	else:
		Global.player.jump_points.erase(self)

	if can_jump and Global.player.dashing and Global.controllable:
		jump(player_face)


func jump(player_face: Vector2) -> void:
	busy = true
	Global.player.shadow(false, remap(height, 0, 0.5, 1, 0))

	for i in waves:
		if is_instance_valid(i):
			wave_go_away(i)

	var prev_z := Global.player.z_index
	Global.player.state = NPC.S.NONE
	Global.player.z_index += 10
	Global.controllable = false
	Global.player.collision(false)

	var coord := get_target_coords(player_face)
	if player_face.y == 0:
		coord.y -= Y_ADJUSTMENT

	Global.player.set_anim("Dash" + Direction.vector_to_string(Global.player.dashdir) + "Loop")
	Global.player.sprite.frame = 0
	await Event.jump_to(Global.player, coord, time, height)

	Global.player.collision(true)
	Global.controllable = true
	
	if to_z == -1:
		Global.player.z_index = prev_z
	else:
		Global.player.z_index = to_z
		Global.player.collision_layer = to_layers
		Global.player.collision_mask = to_layers
	Global.player.move_frames = 0

	Global.player.shadow(true)
	prints("Jump!", name)

	for i in Global.room.followers:
		i.player_jumped = true
		
	busy = false
	Event.teleport_followers()


func get_target_coords(face := Global.player.facing.vector) -> Vector2:
	var coord: Vector2
	if RelativePositions:
		coord = Global.player.position + face * TILE
	else:
		coord = position - face * TILE

	coord += (jump_am * TILE) * face + Vector2(0, jump_am_v * TILE)
	return coord.round()


func jump_target_effect(pos: Vector2) -> void:
	var dub := target.duplicate()
	pos -= dub.get_combined_pivot_offset()
	dub.position = pos
	dub.show()
	add_child(dub)
	waves.append(dub)
	
	var splash_time := 1.4
	var t := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(dub, "scale", Vector2(0.4, 0.4) / scale, splash_time).from(Vector2(1, 1) / scale)
	t.tween_property(dub, "modulate:a", 0.4, splash_time * 0.5).from(0)
	t.tween_property(dub, "modulate:a", 0, splash_time * 0.5).set_delay(splash_time / 2)
	await t.finished
	if is_instance_valid(dub):
		dub.queue_free()


func wave_go_away(wave: TextureRect) -> void:
	if not is_instance_valid(wave):
		return
	var t := create_tween()
	t.tween_property(wave, "modulate:a", 0, 0.2)
	await t.finished
	if is_instance_valid(wave):
		wave.queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == Global.player:
		is_player_inside = true
		if is_instance_valid(timer) and timer.is_stopped():
			timer.start(0.5)


func _on_body_exited(body: Node2D) -> void:
	if body == Global.player:
		is_player_inside = false
		Global.player.jump_points.erase(self)
		if is_instance_valid(timer):
			timer.stop()


func _on_timer_timeout() -> void:
	if self in Global.player.jump_points and Global.controllable:
		var pos: Vector2 = to_local(get_target_coords())
		jump_target_effect(pos)
