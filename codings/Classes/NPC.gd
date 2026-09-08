@tool
@icon("res://art/Icons/Editor/npc.png")
class_name NPC
extends CharacterBody2D
##An extension of [CharacterBody2D] designed for this game. Provides basic movement and interaction.

enum S {IDLE, MOVE, INTERACTING, CONTROLLED, CHASE, CUSTOM, NONE}

## The [String] used to refer to this node through [codeblock]Event.npc(ID)[/codeblock]
## Leave blank to use the name of the node.
@export var ID: String = ""

##Speed of movement
@export var speed := 80

##Used to determine what directions the animations face
@export var facing: Direction = Direction.DOWN

##The default state of the NPC when spawned.
@export var default_state: S = S.IDLE

## The sprite for this NPC, defaults to a child named "Sprite"
@export var sprite: AnimatedSprite2D
## Sprite of this NPC's shadow, defaults to a child named "Shadow"
@export var shadow_sprite: Node2D

## Navigation Agent2D used to pathfind, optional.
@export var Nav: NavigationAgent2D

## Make sounds while walking
@export var footstep_sounds := true
## The frames that the footsteps sound should play on.
@export var step_frames: Dictionary[String, PackedInt32Array] = {
	"Walk": [0, 2],
	"Loop": [0, 1],
}

## Disable collision when this NPC spawns
@export var dont_use_collision := false
@export var no_shadow := false:
	set(x):
		no_shadow = x
		shadow(!x)

##Used to control the direction of the next movement
var direction: Vector2 = Vector2.ZERO

##0: Idle, Not moving[br]
##1: Moving, usually when called by the [method go_to] function[br]
##2: Interacting, doing something other than walking or talking, usuallly with a special animation[br]
##3: Controlled, excludive to [Mira]
##5: Custom
var state: S = S.IDLE:
	set(x):
		#if x != state and self is Mira:
			#print(ID+"'s body state set to ", x)

		state = x

var default_position := Vector2.ZERO
const minimum_movement: float = 0.2
##How many frames the character has been moving
var move_frames := 0
var last_step_frame := -1
var stopping := false
var RealVelocity := Vector2.ZERO
var PrevPosition := Vector2.ZERO
##Coordinates on the [TileMap]
var coords: Vector2 = Vector2.ZERO


func _ready() -> void:
	setup_shadow()
	
	if Engine.is_editor_hint(): return
	
	if ID == "": ID = default_id()
	if has_node("Sprite"): sprite = $Sprite
	state = default_state

	if ID in Loader.defeated: 
		queue_free()
		return

	
	Event.add_char(self)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	if dont_use_collision: collision(false)

	await Event.wait()
	setup_shadow()
	
	if Nav == null: Nav = get_node_or_null("Nav")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	default_position = global_position
	
	default()


func setup_shadow() -> void:
	if sprite:
		if sprite.sprite_frames.has_animation("IdleDown"):
			sprite.offset.y = - sprite.sprite_frames.get_frame_texture("IdleDown", 0).get_size().y / 2 + 7

	if shadow_sprite:
		if no_shadow:
			shadow_sprite.hide()
		else:
			move_child.call_deferred(shadow_sprite, get_child_count() - 1)


func default_id() -> String: return name


func default() -> void: pass


func extended_process() -> void: pass


func attacked() -> void: pass


func control_process() -> void:
	OS.alert("Only Mira can be set to 'Controlled'")
	state = S.IDLE


func _physics_process(delta: float) -> void:
	#move_and_collide(Vector2.ZERO)
	if Engine.is_editor_hint(): return
	if get_tree().paused:
		return

	extended_process()
	if self.get_path() in Loader.defeated: queue_free()
	if Global.room: coords = Global.room.local_to_map(global_position)
	RealVelocity = (PrevPosition - position) / get_physics_process_delta_time()
	PrevPosition = position

	match state:
		S.MOVE, S.CHASE:
			velocity = direction * speed
			move_and_collide(velocity * delta)

		S.IDLE:
			direction = Vector2.ZERO
			#position = round(position)
			move_and_collide(Vector2.ZERO)

		S.CONTROLLED:
			control_process()

		S.CUSTOM:
			velocity = direction * speed
			move_and_collide(velocity * delta)

		S.NONE: return

	if direction.length() > 0.2:
		var dir_marker: Marker2D = get_node_or_null("DirectionMarker")

		if dir_marker:
			set_dir_marker(direction, dir_marker)

		if direction.length() > 0.05: facing.vector = direction

	update_anim_prm()


func set_dir_marker(vec: Vector2 = direction, dir_marker: Marker2D = null) -> void:
	vec = vec.normalized()

	if not dir_marker:
		dir_marker = $DirectionMarker  #maintain compat just in case this function is used elsewhere
	dir_marker.global_position = global_position + vec * 10
	dir_marker.rotation = direction.angle()


func update_anim_prm() -> void:
	if sprite.sprite_frames == null: return
	if footstep_sounds: handle_step_sounds(sprite)
	if state == S.IDLE and not sprite.is_playing(): sprite.play()
	if state == S.CUSTOM: return
	if facing.vector == Vector2.ZERO: return
	if RealVelocity.length() > minimum_movement:
		#BodyState = MOVE

		if str("Walk" + facing.to_string()) in sprite.sprite_frames.get_animation_names():
			sprite.play(str("Walk" + facing.to_string()))
	else:
		#BodyState = IDLE

		if str("Idle" + facing.to_string()) in sprite.sprite_frames.get_animation_names():
			sprite.play(str("Idle" + facing.to_string()))


func handle_step_sounds(for_sprite: AnimatedSprite2D) -> void:
	if not is_instance_valid(for_sprite) or "Idle" in for_sprite.animation:
		last_step_frame = -1
		return

	if not has_node("StdrFootsteps") or for_sprite.frame == last_step_frame or (last_step_frame == -1 and move_frames == 0): return
	last_step_frame = for_sprite.frame
	var frames: PackedInt32Array
	for i in step_frames:
		if i in for_sprite.animation: frames = step_frames.get(i)

	if frames.has(for_sprite.frame):
		var terrain := Global.room.get_terrain(coords)

		if "Generic" == terrain: return
		var rand: int
		if sprite.frame == 0: rand = randi_range(1, 3)
		else: rand = randi_range(4, 6)
		var sound := terrain + str(rand)
		#print(sprite.animation,sprite.frame)
		play_footstep_sound(sound)


func single_footstep() -> void:
	if has_node("StdrFootsteps"):
		var terrain := Global.room.get_terrain(coords)
		var sound := terrain + str(randi_range(1, 6))
		play_footstep_sound(sound)


func play_footstep_sound(sound: String) -> void:
	if $StdrFootsteps.has_node(sound):
		$StdrFootsteps.get_node(sound).play()


func check_terrain(terrain: String, layer := 1) -> bool:
	if get_tile(layer):
		if get_tile(layer).get_custom_data("TerrainType") == terrain:
			return true

	return false


func get_tile(layer: int) -> TileData:
	return Global.room.get_tile(Global.room.local_to_map(global_position), layer)


## Move towards a direction x24
## Input can be a Vector2, String ("U", "R", etc) or Direction
## A vector input can be bigger than 1 to move further
func move_dir(dir: Variant, use_coords := true) -> void:
	var vector: Vector2

	if dir is String: vector = Direction.from_letter(dir).vector
	elif dir is Direction: vector = dir.vector
	elif dir is Vector2: vector = dir
	else:
		push_error("Invalid use of move_dir: ", dir)
		return

	if use_coords: await go_to(position + vector * 24)
	else: await go_to(position + vector)


## The characted looks to a new direction and becomes IDLE
## Input can be a Vector2, String ("U", "R", etc) or Direction
func look_to(dir: Variant) -> void:
	var vector: Vector2

	if dir is String: vector = Direction.from_letter(dir).vector
	elif dir is Direction: vector = dir.vector
	elif dir is Vector2: vector = dir
	else:
		push_error("Invalid use of look_to: ", dir)
		return

	
	state = S.IDLE
	facing.vector = vector
	direction = vector


func pathfind_to(pos: Vector2, exact := true, autostop := true, look_dir: Vector2 = Vector2.ZERO) -> void:
	if Nav == null: return
	if self is Mira and Global.controllable: await Event.take_control()
	#await stop_going()
	Nav.set_target_position(Global.room.map_to_local(pos))
	state = S.MOVE
	#print("Target: ", Vector2(pos))
	while (not Nav.is_target_reached() and (not Global.room.local_to_map(global_position) == Vector2i(pos))) and state == S.MOVE:
		await Event.wait()
		direction = to_local(Nav.get_next_path_position()).normalized()
		#print(not Global.Area.local_to_map(global_position) == Vector2i(pos), not Nav.is_target_reached(), BodyState)

		if Nav == null or ((not Nav.is_target_reachable() or is_on_wall() or get_slide_collision_count() > 0) and autostop) or stopping:
			state = S.IDLE
			return

	if Global.room.map_to_local(pos) != global_position and Global.room.local_to_map(global_position) == Vector2i(pos) and exact:
		#print("finished")
		var t := create_tween()
		t.tween_property(self, "global_position", Global.room.map_to_local(pos), Nav.distance_to_target() / speed)
		await t.finished

	state = S.IDLE
	position = Vector2i(position)
	direction = Vector2.ZERO
	await Event.wait()
	if look_dir != Vector2.ZERO:
		look_to(look_dir)


##Move towards a specific position until arriving.
##if use_coords is true it will use TileMap coordinates instead of a global position.
##If autostop is true, it will stop when hitting a wall.
##look_dir is the direction the NPC will face after reaching the destination.
##accuracy detarmines how close to the destination the NPC should get.
func go_to(pos: Variant, use_coords := false, autostop := false, look_dir: Variant = Vector2.ZERO, accuracy: int = 6) -> void:
	if pos is String:
		pos = Event.get_marker_pos(pos)

	if self is Mira and Global.player.controllable(): return
	await stop_going()
	
	if use_coords: pos *= 24
	
	if Engine.time_scale > 2:
		position = pos
		return

	state = S.MOVE

	while round(global_position / accuracy) != round(pos / accuracy):
		if not is_instance_valid(self) or is_queued_for_deletion():
			return

		state = S.MOVE
		direction = to_local(pos).normalized()
		await Event.wait()
		if (autostop and is_on_wall()) or stopping: break

	direction = Vector2.ZERO
	state = S.IDLE

	if look_dir is String or look_dir != Vector2.ZERO: look_to(look_dir)


func set_anim(anim: String, wait := false, overwrite_state := true) -> void:
	if overwrite_state: state = S.CUSTOM
	if not is_instance_valid(sprite):
		push_warning("Attempted to set animation before sprite was initialized on ", ID)
		return

	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		if wait: await sprite.animation_finished


func stop_going() -> void:
	stopping = true
	await Event.wait()
	stopping = false


func defeat() -> void:
	Loader.defeated.append(ID)
	queue_free()


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("DebugD") and Global.settings.DebugMode:
		go_to(get_global_mouse_position(), false)


func wall_in_front() -> bool:
	if is_on_wall() and Direction.from(get_wall_normal()).equals(facing): return true
	else: return false


func bubble(stri: String) -> void:
	$Bubble.play(stri)
	await $Bubble.animation_finished


func shade(opacity: float = 0.8) -> void:
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(opacity, opacity, opacity, 1), 0.3)


func unshade() -> void:
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, 0.3)


func collision(tog: bool = $CollisionShape2D.disabled) -> void:
	$CollisionShape2D.set_deferred("disabled", not tog)


func chain_moves(moves: Array) -> void:
	for i:Variant in moves:
		await move_dir(i)


func chain_positions(moves: Array[Vector2]) -> void:
	for i in moves:
		if Battle.in_battle:
			await Event.wait()

		await go_to(i)


func hop(height: int = 12, time: float = 0.2) -> void:
	state = S.CUSTOM
	var t: Tween = create_tween()
	t.tween_property(self, "position:y", -height, time / 2).as_relative()
	t.tween_property(self, "position:y", height, time / 2).as_relative()
	await t.finished


func jump_to(to_position: Vector2, time: float = 5, height: float = 0.1, rumble := true) -> void:
	state = S.CUSTOM
	await Event.jump_to_global(self, to_position, time, height, rumble)


func change_sprite(id: String) -> void:
	get_node("Sprite").sprite_frames = await Query.get_ov_sprites(id)


## Toggles the shadow
func shadow(toggle: bool, off_alpha: float = 0) -> void:
	var t := create_tween()

	if toggle:
		t.tween_property(get_node("Shadow"), "modulate:a", 1, 0.1)
	else:
		t.tween_property(get_node("Shadow"), "modulate:a", off_alpha, 0.1)


func bump(dir: Direction = facing) -> void:
	play_footstep_sound("Bump")
	var dir_name := dir.to_string()
	Controller.rumble(0.7, 0.3, 0.08)
	direction = Vector2.ZERO
	Event.jump_to_global(self, global_position - dir.vector * 15, 15, 0.5, false)
	await set_anim("Dash" + dir_name + "Hit", true, false)
