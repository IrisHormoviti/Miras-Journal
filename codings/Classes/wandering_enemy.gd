@tool
@icon("res://art/Icons/Editor/enemy.png")
extends NPC

@export_tool_button("Add Homepoints and Sprites", "Add") var add_node_button: Callable = add_nodes
@export_tool_button("Apply positions", "CheckBox") var set_positions_button: Callable = set_positions
@export var BattleSeq: BattleSequence
@export var Defeated := false
@export var give_up_after := 3
@export var patrol_speed := 20
@export var chase_speed := 40

var lock := false
var homepoints: Array[Vector2]
var PinRange := false
var CurHomepoint: Vector2 = Vector2.ZERO

@onready var tmr: Timer = $Timer


func add_nodes() -> void:
	if get_node_or_null("HomePoints") == null:
		var this_homepoints := Node2D.new()
		this_homepoints.name = "HomePoints"
		add_child(this_homepoints)
		this_homepoints.owner = $".."
		var marker := Marker2D.new()
		marker.name = "1"
		this_homepoints.add_child(marker)
		marker.owner = $".."

	if get_node_or_null("Sprite") == null:
		var this_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		this_sprite.name = "Sprite"
		this_sprite.sprite_frames = await Loader.load("res://art/OV/Enemies/GenericEnemy.tres")
		add_child(this_sprite)
		this_sprite.owner = $".."

	var esc_marker: Marker2D = get_node_or_null("EscapePosition")

	if esc_marker == null:
		esc_marker = Marker2D.new()
		esc_marker.name = "EscapePosition"
		add_child(esc_marker)
		esc_marker.owner = $".."

	var scn_marker: Marker2D = get_node_or_null("ScenePosition")

	if scn_marker == null:
		scn_marker = Marker2D.new()
		scn_marker.name = "ScenePosition"
		add_child(scn_marker)
		scn_marker.owner = $".."

	if BattleSeq != null:
		esc_marker.global_position = BattleSeq.EscPosition * 24
		scn_marker.global_position = BattleSeq.ScenePosition
		scn_marker.gizmo_extents = 100


func set_positions() -> void:
	var scn_marker: Marker2D = get_node_or_null("ScenePosition")

	if scn_marker != null and BattleSeq != null:
		BattleSeq.ScenePosition = scn_marker.global_position

	var esc_marker: Marker2D = get_node_or_null("EscapePosition")

	if esc_marker != null and BattleSeq != null:
		BattleSeq.EscPosition = Vector2i(esc_marker.global_position / 24)


func default() -> void:
	Nav = $Nav

	if ID == "":
		ID = name

	if ID in Loader.defeated:
		queue_free()

	if get_node_or_null("HomePoints") != null:
		for i in $HomePoints.get_children():
			homepoints.append(i.global_position)

	for i in Global.room.followers:
		add_collision_exception_with(i)

	patrol()


func patrol() -> void:
	stopping = false
	Loader.chased = false
	PinRange = false


func extended_process() -> void:
	var Collision: CollisionShape2D = $Collision

	if self.get_path in Loader.defeated:
		hide()
		$CatchArea/CollisionShape2D.set_deferred("disabled", true)
		return

	if PinRange and tmr:
		stopping = true

		if tmr.time_left != 0:
			Collision.set_deferred("disabled", false)
			state = S.CHASE

			if Global.player in $DirectionMarker/Finder.get_overlapping_bodies():
				Nav.set_target_position(Global.player.position)
				if tmr.time_left < 2 and Nav.is_target_reachable():
					tmr.start(2)

			if Direction.snap_vector(to_local(Nav.get_next_path_position())) != -Direction.snap_vector(direction):
				direction = to_local(Nav.get_next_path_position()).normalized()
		else:
			if not Battle.in_battle:
				Loader.battle_bars(0)

			patrol()
			if Battle.attacker == self:
				Battle.attacker = null
	else:
		if Battle.in_battle:
			hide()
		elif not homepoints.is_empty() and tmr.time_left == 0 and not stopping:

			if is_on_wall():
				Event.jump_to_global(self, CurHomepoint)

			if round(position / 24) == round(CurHomepoint / 24):
				tmr.start(randf_range(0, 3))
				CurHomepoint = Vector2.ZERO
				state = S.IDLE
			else:
				show()
				Collision.set_deferred("disabled", true)
				speed = patrol_speed
				state = S.MOVE

				if CurHomepoint == Vector2.ZERO:
					CurHomepoint = homepoints.pick_random()

				direction = to_local(CurHomepoint).normalized()


func begin_battle(advatage := 0) -> void:
	Battle.attacker = self
	Global.player.dramatic_attack_pause()
	Controller.rumble(1, 1, 0.2)
	await Battle.start(BattleSeq, advatage)
	global_position = default_position


func attacked() -> void:
	if Global.player.winding_attack:
		return

	state = S.NONE
	set_anim("Hit")
	var to_pos := position + facing.vector * 12
	Event.jump_to_global(self, to_pos, 25, 1)
	Global.player.camera_follow(false)
	Global.camera.position = to_pos
	Global.intro_effect(self)
	if PinRange:
		begin_battle()
	else:
		begin_battle(1)


func _on_finder_body_entered(body: Node2D) -> void:
	if body == Global.player and not PinRange and not Loader.chased and not Battle.in_battle:
		Nav.set_target_position(Global.player.position)
		if not Nav.is_target_reachable():
			return

		stopping = true
		Loader.chase_mode()
		Loader.battle_bars(1)
		set_dir_marker(to_local(Global.player.global_position))
		state = S.IDLE
		direction = Vector2.ZERO
		$Bubble.play("Surprise")
		Battle.attacker = self
		look_to(Direction.snap_vector(to_local(Global.player.global_position)))
		await Event.wait(0.8)
		look_to(Direction.snap_vector(to_local(Global.player.global_position)))
		speed = chase_speed
		set_dir_marker(to_local(Global.player.global_position))
		await Event.wait()
		#if not Global.Player in $DirectionMarker/Finder.get_overlapping_bodies() or not Nav.is_target_reachable():
		#$Bubble.play("Ellipsis")
		#patrol()
		state = S.MOVE
		tmr.start(give_up_after)
		PinRange = true


func _on_catch_area_body_entered(body: Node2D) -> void:
	if (body == Global.player and (not lock) and (not Battle.in_battle) and (not Global.player.attacking or Global.player.winding_attack)):
		#print(Global.Player.attacking)
		$EnemyStrike.disappear()
		Global.player.winding_attack = false
		await Event.take_control(false, false, false)
		Global.player.dashdir = Direction.snap_vector(Global.player.to_local(global_position))
		Global.player.get_node("Flame").energy = 0
		Global.player.bump()
		facing.vector = to_local(Global.player.position)
		Global.intro_effect(Global.player)
		begin_battle(2)


func _on_strike_area_entered(area: Area2D) -> void:
	if area.name == "Attack":
		attacked()
