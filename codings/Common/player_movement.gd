@tool
extends NPC
class_name Mira
##The script that handles's Mira's movment

const DASH_SPEED := 200
const WALK_SPEED := 100

##Whether the dash is active
var dashing := false
var winding_attack := false
##When the player is supposed to be in a midair perspective
var midair := false
##true is there is a wall in front of the player
var undashable := false
##Direction of the dash
var dashdir: Vector2 = Vector2.ZERO
##Use flame to light up the enviroment
@export var can_dash := true
var first_frame := true
@onready var flame: PointLight2D = $Flame
var attacking := false
var is_clone: bool = false
var jump_points: Array[JumpPoint]
var cant_bump := false
var path: Path2D
var flame_active := false
var local_controllable := true:
	set(x):
		local_controllable = x

signal initialized


func _ready() -> void:
	collision(false)
	if is_clone: ID = "MenuPlayer"
	else: ID = "P"
	Event.add_char(self)
	Item.pickup.connect(_on_pickup)
	Global.check.connect(_check_party)
	await Event.wait()
	path = Path2D.new()
	Global.room.add_child(path)
	path.curve = Curve2D.new()
	sprite = %Base

	if Global.room == null:
		OS.alert("THIS IS THE PLAYER SCENE", "WRONG SCENE IDIOT")
		Loader.travel_to("Debug")
		queue_free()
		return

	Battle.in_battle = false

	if not is_clone:
		Global.player = self
		var cam: Camera2D = Global.camera

		if cam != null:
			Global.room.cam.enabled = false
			$Camera2D.remote_path = cam.get_path()
			cam.enabled = true

	set_anim("Idle" + facing.to_string())
	$Attack/CollisionShape2D.disabled = true
	$Attack/AttackPreview/CollisionShape2D.disabled = true
	local_controllable = true
	initialized.emit()


#func _process(delta: float) -> void:
	#Steam.run_callbacks()
	#Steam.runFrame()


func extended_process() -> void:
	if is_instance_valid(path):
		if RealVelocity.length() > 350:
			path.curve.clear_points()

		if path.curve.point_count < 2:
			path.curve.add_point(position - facing.vector * 24)
			path.curve.add_point(position - facing.vector)

		path.curve.set_point_position(path.curve.point_count - 1, position)
		if (path.curve.get_point_position(path.curve.point_count - 1) 
			- path.curve.get_point_position(path.curve.point_count - 2)).length() > 24:
			path.curve.add_point(position.round()
		)

	if controllable():
		state = S.CONTROLLED
		#check_flame()
	else:
		first_frame = true

		if state == S.CONTROLLED:
			state = S.CUSTOM


func control_process() -> void:
	if first_frame:
		if Engine.time_scale > 1: Engine.time_scale = 1
		$Attack/CollisionShape2D.set_deferred("disabled", true)
		first_frame = false
		reset_speed()

	if Global.room: coords = Global.room.local_to_map(global_position)
	direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down", 0.1)

	if abs(direction.x) < 0.1: direction.y += direction.x; direction.x = 0
	if abs(direction.y) < 0.1: direction.x += direction.y; direction.y = 0
	undashable = false

	if is_on_wall():
		if round(get_wall_normal()) * -1 == Direction.snap_vector(direction):
			if not jump_points.is_empty() and Input.is_action_pressed("Dash"):
				position -= direction * 6
			else:
				undashable = true

	if controllable():
		if "Dash" in %Base.animation and not dashing:
			stop_dash()

		if (
			(Input.is_action_pressed("Dash")) and
			not Direction.from(direction).is_vector(dashdir * Vector2(-1, -1))
			and direction != Vector2.ZERO and can_dash
		):
			if dashing:
				if dashdir.y == 0:
					direction.y /= 1.2

			if dashdir.x == 0:
				direction.x /= 1.2

			speed = min(speed * 1.005, 350)

			if not dashing:
				if undashable:
					reset_speed()
					await set_anim("Deny" + facing.to_string(), true)
					set_anim()
					return
				dashdir = Direction.snap_vector(direction)
				dashing = true
				local_controllable = false
				state = S.CUSTOM
				direction = dashdir
				reset_speed()
				if state == S.CUSTOM:
					local_controllable = true

				if speed < DASH_SPEED:
					speed = DASH_SPEED
			elif Direction.snap_vector(direction.normalized()) != dashdir:
				stop_dash()
		elif dashing:
			stop_dash()

		if dashing:
			velocity = ((dashdir + direction).normalized() * speed)
		else:
			velocity = direction * speed

		#if RealVelocity != Vector2.ZERO:
			#if RealVelocity.x == 0: position.x = roundf(position.x)
			#if RealVelocity.y == 0: position.y = roundf(position.y)

		if direction.length() > 0.1:
			move_and_slide()

		#position = round(position)

		if Input.is_action_just_pressed("OVAttack") and controllable():
			attack()

	if Global.settings.DebugMode:
		if Input.is_action_just_pressed("DebugF"):
			Global.toast("Collision set to " + str($CollisionShape2D.disabled))
			$CollisionShape2D.disabled = not $CollisionShape2D.disabled


func update_anim_prm() -> void:
	if get_node_or_null("%Base") == null: return
	if footstep_sounds: handle_step_sounds(sprite)
	if state == S.CUSTOM: return
	if facing.is_vector(Vector2.ZERO): return
	if state == S.CONTROLLED:
		var dir_name: String = facing.to_string()

		if (abs(RealVelocity.length()) > 1 and controllable()):
			if dashing:
				reset_speed()
				var dash_dir_name := Direction.from(dashdir).to_string()

				if has_anim("Dash" + dash_dir_name + "Loop"):
					set_anim("Dash" + dash_dir_name + "Loop", false, false)
				else: set_anim("Walk" + dash_dir_name, false, false)
			else:
				speed = min(WALK_SPEED, speed)
				set_anim(str("Walk" + dir_name), false, false)

			if move_frames < 0:
				move_frames = 0

			move_frames += 1
		elif(
			controllable() and
			("Walk" in sprite.animation or ("Dash" in sprite.animation and dashdir == Vector2.ZERO))
		):
			move_frames = 0
			reset_speed()
			set_anim(str("Idle" + dir_name), false, false)
		else:
			move_frames -= 1

		if direction.length() > RealVelocity.length() and dashing and jump_points.is_empty():
			stop_dash()
	else:
		var dir_name := facing.to_string()

		if RealVelocity.length() > 1:
			if dashing:
				set_anim("Dash" + dir_name + "Stop", false, false)
			else:
				set_anim(str("Walk" + dir_name), false, false)
		else:
			#if RealVelocity == Vector2.ZERO and not is_on_wall():
				#position = round(position)

			set_anim(str("Idle" + dir_name), false, false)


##Item pickup animation
func _on_pickup() -> void:
	await Event.take_control(true, true)
	if facing.equals(Direction.LEFT): await set_anim("PickUpLeft", true, true)
	else: await set_anim("PickUpRight", true, true)
	Event.give_control()
	set_anim()


func _check_party() -> void:
	check_flame()
	if get_node_or_null("%Base") == null: return
	elif is_instance_valid(Party.Leader):
		if not %Base.sprite_frames.resource_path.ends_with(Party.Leader.codename + Party.Leader.OV + ".tres"):
			%Base.sprite_frames = await Party.Leader.get_OV()


##Sets the animation for all sprite layers
func set_anim(anim: String = "Idle" + facing.to_string(), wait := false, overwrite_bodystate := true) -> void:
	if get_node_or_null("%Base") == null: return
	if not controllable(): reset_speed()
	if overwrite_bodystate: state = S.CUSTOM
	if flame_active and has_anim(anim, %Flame):
		sprite = %Flame
	elif has_anim(anim):
		sprite = %Base
	else:
		if wait: await Event.wait()
		return

	hide_other_sprites()
	#print(sprite.name, " ", anim)
	sprite.play(anim)
	if wait:
		while sprite.is_playing() and sprite.animation == anim:
			await get_tree().physics_frame


func has_anim(anim: String, node: AnimatedSprite2D = %Base) -> bool:
	return anim in node.sprite_frames.get_animation_names()


func hide_other_sprites() -> void:
	for i in $Sprite.get_children():
		if i == sprite: i.show()
		elif i == %Flame and flame_active and sprite != %Flame:
			flame_out_of_the_way()
		else: i.hide()


func flame_out_of_the_way() -> void:
	if "Flame"not in %Flame.animation:
		%Flame.show()
		%Flame.play("FlameGo")
		await %Flame.animation_finished
		if "Flame" in %Flame.animation: %Flame.play("FlameFloat")

	#elif "Stop" in anim:
		#%Flame.play_backwards("FlameGo")


func activate_flame(animate := true) -> void:
	Event.add_flag(&"FlameActive")
	await Event.wait()
	check_flame(true)
	if animate:
		local_controllable = false
		state = S.NONE
		await set_anim("FlameActive", true, false)
		set_anim("IdleRight", false)
		local_controllable = true


func check_flame(force := false) -> void:
	if not controllable() and not force: return
	flame_active = Event.check_flag(&"FlameActive")

	if flame_active:
		if get_node_or_null("Flame") == null: return
		if flame.energy == 0:
			flame.flicker = true

			if not force: activate_flame(false)
			while flame.energy < 1.5:
				flame.energy += 0.03
				await Event.wait()

			flame.energy = 1.5
			flame.flicker = true
	elif get_node_or_null("Flame") and flame.energy != 0:
		#reset_sprite()
		flame.flicker = false
		flame.energy = 0


func reset_sprite() -> void:
	_check_party()


##For opening the menu
func bag_anim() -> void:
	state = S.NONE

	if get_node_or_null("%Base") == null: return
	Party.get_member("Mira").OV = "Bag"
	Global.check.emit()
	await set_anim("BagOpen", true)
	set_anim("BagIdle")


## Handles the animation when the dash is stopped, either doing the slide or hit one 
## depending on the wall in front of her
func stop_dash(slide := true) -> void:
	if (state != S.CONTROLLED or "Stop" in sprite.animation or "Hit" in
	sprite.animation or midair or not dashing): return
	dashing = false
	reset_speed()
	if (undashable and Direction.snap_vector(direction) == dashdir) and move_frames > 5:
		speed = WALK_SPEED
		await bump()
	else:
		set_anim("Dash" + Direction.from(dashdir).to_string() + "Stop", false, false)
		local_controllable = false

		if (
			Input.is_action_pressed("Dash") and
			Direction.snap_vector(direction) != dashdir and
			direction != Vector2.ZERO and
			not Direction.snap_vector(direction) == -dashdir
		):
			await get_tree().create_timer(0.1).timeout
		else:
			speed = WALK_SPEED

			if slide:
				while sprite.is_playing() and "Stop" in sprite.animation:
					if direction == Vector2.ZERO:
						direction = dashdir * 0.3
						speed = max(0, speed - 2)

					velocity = dashdir * speed
					speed = max(0, speed - 2)
					await Event.wait()

		local_controllable = true
		Global.check.emit()
		state = S.CONTROLLED
		velocity = Vector2.ZERO

	dashdir = Vector2.ZERO
	move_frames = 0
	speed = WALK_SPEED

	if "Stop" in sprite.animation or "Hit" in sprite.animation:
		set_anim(str("Idle" + Direction.vector_to_string(dashdir)), false)


func reset_speed() -> void:
	if get_node_or_null("%Base") == null: return
	for i in $Sprite.get_children():
		i.speed_scale = 1


func bump(dir: Direction = facing) -> void:
	play_footstep_sound("Bump")
	var dir_name := dir.to_string()

	if cant_bump or not has_anim("Dash" + dir_name + "Hit"): return
	winding_attack = false
	Controller.rumble(0.7, 0.3, 0.08)
	direction = Vector2.ZERO

	if dir.is_vector(Vector2.ZERO):
		dir.set_to(dashdir)

	Event.jump_to_global(self, global_position - dir.vector * 15, 15, 0.5, false)
	set_anim("Dash" + dir_name + "Hit", false)
	var mem := local_controllable
	local_controllable = false
	await Event.wait(0.2)
	single_footstep()
	if sprite.is_playing(): await sprite.animation_finished
	local_controllable = mem


func camera_follow(follow: bool = false) -> void:
	$Camera2D.update_position = follow


func controllable() -> bool:
	return local_controllable and Global.controllable


func attack() -> void:
	if not Item.check_item("LightweightAxe") or not Event.check_flag("HasBag"):
		Audio.buzzer_sound()
		return

	if dashing: await stop_dash()
	reset_speed()
	speed = 40
	local_controllable = false
	$DirectionMarker/Finder/Shape.disabled = true
	$Attack/AttackPreview.collision_layer = collision_layer
	$Attack/AttackPreview.collision_mask = collision_mask
	$Attack/AttackPreview/CollisionShape2D.disabled = false
	var checked := false
	attacking = true
	await Event.wait()
	check_before_attack()
	var dir_name := facing.to_string()
	$Attack.rotation = facing.vector.angle()

	if RealVelocity.length() > 1:
		set_anim("Attack" + dir_name + "Walk", false, false)
		await Event.wait(0.4)
	else:
		await set_anim("Attack" + dir_name + "Windup", true, false)

	winding_attack = true

	while Input.is_action_pressed("OVAttack") or not checked:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down", 0.4)

		if direction != Vector2.ZERO and RealVelocity.length() > 0.1:
			var mation := "Attack" + dir_name + "Walk"

			if sprite.animation != mation:
				set_anim(mation, false, false)
		else:
			var mation := "Attack" + dir_name + "Windup"
			sprite.animation = mation
			sprite.frame = 1

		check_before_attack()
		if not winding_attack:
			attacking = false
			state = S.IDLE
			set_anim()
			$Attack/AttackPreview/CollisionShape2D.disabled = false
			$Attack/CollisionShape2D.disabled = false
			speed = WALK_SPEED
			return

		checked = true
		await get_tree().physics_frame

	winding_attack = false
	$Attack/CollisionShape2D.disabled = false
	var hits := false
	state = S.CUSTOM
	direction = Vector2.ZERO
	await get_tree().physics_frame
	for i: Node2D in $Attack/AttackPreview.get_overlapping_bodies():
		#print(i)
		if not (i is NPC or i is Follower or i is Mira):
			hits = true

	#print("pt1: " + str(hits))
	for i: Node2D in $Attack.get_overlapping_bodies():
		#print(i)
		if (i is NPC or i is Follower) and not i is Mira:
			hits = false

	#print("pt2: " + str(hits))
	var audio := preload("res://sound/SFX/Swing.ogg")
	var anim := "Attack" + facing.to_string()

	if hits:
		anim = "Attack" + facing.to_string() + "Hit"
		audio = preload("res://sound/SFX/AxeBlock.ogg")
		Controller.rumble(0.3, 0.3, 0.1, 0.1)

	$Audio.stream = audio
	$Audio.play()
	await set_anim(anim, true)
	local_controllable = true
	$DirectionMarker/Finder/Shape.disabled = false

	if Input.is_action_pressed("OVAttack"): attack()
	else:
		attacking = false
		set_anim()
		speed = WALK_SPEED
		$Attack/CollisionShape2D.disabled = true
		$Attack/AttackPreview/CollisionShape2D.disabled = true


func check_before_attack() -> void:
	$Attack.rotation = facing.vector.angle()

	for i: Node2D in $Attack/AttackPreview.get_overlapping_bodies():
		if i is NPC or i is Follower:
			i.attacked()


func dramatic_attack_pause() -> void:
	while not controllable():
		local_controllable = false
		state = S.CUSTOM
		#print(attacking)
		if attacking:
			set_anim("Attack" + facing.to_string())
			pause_anim()
			var timer := get_tree().create_timer(3)

			while timer.time_left > 0:
				sprite = %Base
				hide_other_sprites()
				%Base.animation = "Attack" + facing.to_string()
				%Base.frame = 1
				await Event.wait()

			set_anim()
		else:
			set_anim("Dash" + facing.to_string() + "Hit")
			pause_anim()

		await Event.wait()


func remove_light(node: Node2D = $Sprite) -> void:
	for i in node.get_children():
		i.light_mask = 0
		remove_light(i)


func pause_anim(node: Node2D = $Sprite) -> void:
	for i in node.get_children():
		if i is AnimatedSprite2D:
			i.pause()
			pause_anim(i)


func flip_sprites(node: Node2D) -> void:
	for i in node.get_children():
		if i is Sprite2D: i.flip_h = true
		if i.get_child_count() != 0: flip_sprites(i)
