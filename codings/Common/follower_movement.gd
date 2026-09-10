@tool
extends NPC
class_name Follower

var oposite: Vector2 = Vector2.ZERO
var moving: bool = false
var target: Vector2 = Vector2.ZERO
var path: Path2D
var follow: PathFollow2D

@export var member: int:
	set(x):
		member = x
		actor = member_info()
@export var actor: Actor
@export var distance: int = 30
@export var dont_follow: bool = false:
	set(x):
		dont_follow = x

		if dont_follow and state == S.CONTROLLED:
			state = S.IDLE
		elif not dont_follow:
			state = S.CONTROLLED
@export var offset: int = 0


func default() -> void:
	hide()
	Global.check.connect(update)

	await Event.wait()

	if not is_instance_valid(Global.player):
		return

	oposite = (Global.player.facing.vector * Vector2(-1, -1)) * 150.0
	set_anim("Idle" + Global.player.facing.to_string())
	velocity = oposite
	path = Global.player.path
	follow = PathFollow2D.new()
	follow.name = name + "Path"
	path.add_child(follow)
	follow.cubic_interp = true
	update()
	await Event.wait(0.1)
	follow.progress = -distance
	position = follow.global_position
	state = S.CONTROLLED


func default_id() -> String:
	return "F" + str(member)


func control_process() -> void:
	if not is_instance_valid(Global.player):
		return

	if dont_follow:
		direction = Vector2.ZERO
		moving = false
		state = S.IDLE
		move_and_slide()
		return

	if not actor or Battle.in_battle or not is_instance_valid(follow):
		hide()
		return

	add_collision_exception_with(Global.player)
	for follower: Variant in Global.room.followers:
		add_collision_exception_with(follower)

	show()
	z_index = Global.player.z_index
	collision_layer = Global.player.collision_layer
	collision_mask = Global.player.collision_mask
	$Glow.color = actor.MainColor
	$Glow.energy = actor.GlowDef / 2.0

	var old_position: Vector2 = global_position
	var player_dist: float = to_local(Global.player.position).length()

	follow.progress = lerpf(follow.progress, maxf(path.curve.get_baked_length() - distance, 0.0), 0.35)

	target = follow.global_position + follow.transform.y * float(offset)
	var target_vec: Vector2 = to_local(target)
	var target_dist: float = target_vec.length()

	if target_dist < 3.0:
		direction = Vector2.ZERO
		speed = 0
	else:
		direction = target_vec.normalized()
		var max_allowed_speed: float = Global.player.speed * 1.5
		speed = int(clampf(Global.player.speed * (target_dist / 20.0), 30.0, max_allowed_speed))

	if floor(player_dist / 5.0) < floor(distance / 5.0):
		speed /= 2

	if player_dist > 180.0:
		jump_to_player()

	if player_dist < 12.0 and Global.controllable:
		update_anim_prm()
		oposite = Global.player.facing.vector * Vector2(-1, -1)
		velocity = oposite * 150.0

	velocity = speed * direction
	move_and_slide()

	var delta: float = get_physics_process_delta_time()

	if (global_position - old_position).length() > 0.1 and delta > 0.0:
		moving = true
		RealVelocity = (global_position - old_position) / delta
	else:
		moving = false
		RealVelocity = Vector2.ZERO


func jump_to_player(jump_speed: int = 2) -> void:
	if not is_instance_valid(Global.player):
		return

	if Global.player.dashing:
		return

	position = Global.player.position


func _on_timer_timeout() -> void:
	if Party.has_member_index(member):
		update_anim_prm()


func member_info() -> Actor:
	return Party.get_member_index(member)


func attacked() -> void:
	Event.jump_to(self, position - Vector2(Global.player.facing.vector * 24.0), 5.0, 0.5)


func update() -> void:
	if not Party.has_member_index(member):
		return

	actor = Party.get_member_index(member)

	if actor != null and sprite.sprite_frames and sprite.sprite_frames.resource_path != actor.OV:
		sprite.sprite_frames = await actor.get_OV()

		if actor and shadow_sprite:
			shadow(actor.Shadow)
