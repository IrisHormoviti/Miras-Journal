@tool
@icon("res://art/Icons/Editor/enemy.png")
extends NPC

@export_tool_button("Add Homepoints and Sprites", "Add") var add_node_button: Callable = add_nodes
@export_tool_button("Apply positions", "CheckBox") var set_positions_button: Callable = set_positions
@export var battle_sequence: BattleSequence
@export var defeated := false
@export var give_up_after := 3
@export var patrol_speed := 20
@export var chase_speed := 40
@export var max_chase_distance: float = 200.0

var lock := false
var homepoints: Array[Vector2]
var current_path_index := 0
var pin_range := false
var spotting_player := false
var cur_homepoint := Vector2.ZERO

@onready var tmr: Timer = $Timer


func add_nodes() -> void:
	if get_node_or_null("PatrolPath") == null:
		var this_path := Path2D.new()
		this_path.name = "PatrolPath"
		this_path.curve = Curve2D.new()
		this_path.curve.add_point(Vector2.ZERO)
		add_child(this_path)
		this_path.owner = $".."

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

	if battle_sequence != null:
		esc_marker.global_position = battle_sequence.EscPosition * 24
		scn_marker.global_position = battle_sequence.ScenePosition
		scn_marker.gizmo_extents = 100


func set_positions() -> void:
	var scn_marker: Marker2D = get_node_or_null("ScenePosition")
	if scn_marker != null and battle_sequence != null:
		battle_sequence.ScenePosition = scn_marker.global_position

	var esc_marker: Marker2D = get_node_or_null("EscapePosition")
	if esc_marker != null and battle_sequence != null:
		battle_sequence.EscPosition = Vector2i(esc_marker.global_position / 24)


func default() -> void:
	Nav = $Nav
	if is_instance_valid(Nav):
		Nav.simplify_path = false
		Nav.path_desired_distance = 4.0
		Nav.target_desired_distance = 4.0

	Global.battle_end.connect(func() -> void:
		process_mode = Node.PROCESS_MODE_INHERIT
		show()
		patrol()
		lock = true
		get_tree().create_timer(2.0).timeout.connect(func() -> void: lock = false)
	)

	if ID == "":
		ID = name

	if defeated or ID in Loader.defeated:
		queue_free()

	homepoints.clear()
	if has_node("PatrolPath"):
		var path: Path2D = get_node("PatrolPath")
		if path.curve:
			for i in range(path.curve.point_count):
				homepoints.append(path.to_global(path.curve.get_point_position(i)))

	for follower in Global.room.followers:
		add_collision_exception_with(follower)

	patrol()


func patrol() -> void:
	stopping = false
	pin_range = false
	spotting_player = false
	speed = patrol_speed
	cur_homepoint = Vector2.ZERO

	if not homepoints.is_empty():
		var nearest_idx := 0
		var nearest_dist := INF
		for i in range(homepoints.size()):
			var dist := global_position.distance_to(homepoints[i])
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_idx = i
		current_path_index = nearest_idx


func extended_process() -> void:
	var collision_shape: CollisionShape2D = $Collision

	if defeated or ID in Loader.defeated or get_path() in Loader.defeated:
		hide()
		$CatchArea/CollisionShape2D.set_deferred("disabled", true)
		return

	if pin_range and is_instance_valid(tmr):
		stopping = true

		if tmr.time_left != 0:
			collision_shape.set_deferred("disabled", false)

			if state == S.CHASE:
				speed = chase_speed
				Nav.set_target_position(Global.player.global_position)

				var dist_to_player := global_position.distance_to(Global.player.global_position)
				if dist_to_player <= max_chase_distance and Nav.is_target_reachable():
					tmr.start(give_up_after)
					var next_pos := Nav.get_next_path_position()
					if next_pos.distance_to(global_position) > 1.0:
						direction = to_local(next_pos).normalized()
		else:
			if not Battle.in_battle:
				Loader.battle_bars(0)
			patrol()
			if Battle.attacker == self:
				Battle.attacker = null
	else:
		if Battle.in_battle:
			modulate.a = 0
		elif tmr.time_left == 0 and not stopping:
			modulate.a = 1

			if homepoints.is_empty():
				if cur_homepoint == Vector2.ZERO:
					cur_homepoint = default_position
			else:
				if cur_homepoint == Vector2.ZERO:
					cur_homepoint = homepoints[current_path_index]
					current_path_index = (current_path_index + 1) % homepoints.size()

			if global_position.distance_to(cur_homepoint) < 8 or (is_instance_valid(Nav) and Nav.is_target_reached()):
				tmr.start(randf_range(0, 3))
				cur_homepoint = Vector2.ZERO
				state = S.IDLE
			else:
				show()
				collision_shape.set_deferred("disabled", true)
				speed = patrol_speed
				state = S.MOVE

				if is_instance_valid(Nav):
					Nav.set_target_position(cur_homepoint)
					var next_pos := Nav.get_next_path_position()
					if next_pos.distance_to(global_position) > 1.0:
						direction = to_local(next_pos).normalized()
					else:
						direction = to_local(cur_homepoint).normalized()
				else:
					direction = to_local(cur_homepoint).normalized()

		if not pin_range and not Battle.in_battle and not Battle.prevent_battles and not lock:
			if has_node("DirectionMarker/Finder") and is_instance_valid(Global.player):
				if Global.player in $DirectionMarker/Finder.get_overlapping_bodies():
					try_spot_player()


func begin_battle(advantage := 0) -> void:
	Battle.attacker = self
	Global.player.dramatic_attack_pause()
	Controller.rumble(1, 1, 0.2)
	await Battle.start(battle_sequence, advantage)
	global_position = default_position
	patrol()
	lock = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void: lock = false)


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
	if pin_range:
		begin_battle()
	else:
		begin_battle(1)


func try_spot_player() -> void:
	if spotting_player or pin_range or lock or Battle.in_battle or Battle.prevent_battles or not is_instance_valid(Global.player):
		return

	spotting_player = true
	Nav.set_target_position(Global.player.global_position)
	await get_tree().physics_frame

	if not is_instance_valid(self) or not is_instance_valid(Global.player) or lock or Battle.in_battle or Battle.prevent_battles or not Nav.is_target_reachable():
		spotting_player = false
		return

	pin_range = true
	spotting_player = false
	tmr.start(give_up_after + 2.0)

	stopping = true
	Loader.chase_mode()
	Loader.battle_bars(1)
	set_dir_marker(to_local(Global.player.global_position))
	state = S.IDLE
	direction = Vector2.ZERO
	$Bubble.play("Surprise")
	Battle.attacker = self
	look_to(Direction.from(to_local(Global.player.global_position)))

	await Event.wait(0.8)
	if not pin_range or lock or Battle.in_battle or not is_instance_valid(Global.player):
		patrol()
		return

	tmr.start(give_up_after)
	speed = chase_speed
	state = S.CHASE


func _on_finder_body_entered(body: Node2D) -> void:
	if body == Global.player:
		try_spot_player()


func _on_catch_area_body_entered(body: Node2D) -> void:
	if body == Global.player and not lock and not Battle.in_battle and not Battle.prevent_battles and (not Global.player.attacking or Global.player.winding_attack):
		if has_node("EnemyStrike"):
			$EnemyStrike.disappear()

		Global.player.winding_attack = false
		await Event.take_control(false, false, false)
		Global.player.dashdir = Direction.snap_vector(Global.player.to_local(global_position))
		Global.player.get_node("Flame").energy = 0
		Global.player.bump()
		facing.vector = to_local(Global.player.global_position)
		Global.intro_effect(Global.player)
		begin_battle(2)


func _on_catch_area_area_entered(_area: Area2D) -> void:
	pass


func _on_strike_area_entered(area: Area2D) -> void:
	if area.name == "Attack":
		attacked()
