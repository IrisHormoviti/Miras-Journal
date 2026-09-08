extends Node
## This Autoload handles the movment of [NPC] nodes and 
## provides useful functions for scripting cutscenes

signal time_changed
signal next_day
signal anim_done
signal textbox_close
signal passive_close

enum TOD {DARKHOUR = 0, MORNING = 1, DAYTIME = 2, AFTERNOON = 3, EVENING = 4, NIGHT = 5}

##An [Array] of all [NPC] nodes in the current scene
var npc_list: Dictionary[String, NPC]
## object_list identified with object identifier script
var object_list: Dictionary[String, Node2D]
## Various values for remembering game states
var flags: Dictionary[StringName, int]
## diary entries for the journal
var diary: Dictionary[int, PackedStringArray]

var day: int:
	set(x):
		day = x
		add_flag("day", x)
var month: String = "November"
var time_of_day := TOD.DARKHOUR:
	set(x):
		time_of_day = x
		add_flag("time", x)

## New time for the next time transition
var to_time := TOD.DARKHOUR
var to_day: int

@onready var sequences: Node = $Sequences


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


##Character is added to the list of NPCS
func add_char(b: NPC) -> void:
	if npc_list.has(b.ID) and is_instance_valid(npc_list.get(b.ID)):
		push_warning("Duplicate npc spawned: ", b.ID)
		if is_instance_valid(npc_list.get(b.ID)):
			return

	if not is_instance_valid(b) or not b.is_inside_tree(): return

	npc_list.set(b.ID, b)
	DialogueManager.unregister_state_context(b.ID)

	var context := DialogueStateContext.new()
	context.target = b
	context.alias = b.ID
	b.add_child(context)


##Get the [NPC] node from a [String] ID
func npc(id: String) -> NPC:
	var rtn: NPC = npc_list.get(id)

	if not is_instance_valid(rtn):
		push_error("NPC with id ", id, " isn't valid.")

	return rtn


func obj(id: String) -> Node2D:
	return object_list.get(id)


##Move an [NPC] relative to their current coords
func move_dir(dir: Vector2 = Global.get_direction(), chara: String = "P") -> void:
	await npc(chara).move_dir(dir)


##Move an [NPC] to the specified coords
func move_to(pos: Vector2 = Global.get_direction(), chara: String = "P") -> void:
	await npc(chara).go_to(pos)


## Wait a specified amount of time or one frame by default
## short for:
## [codeblock]
## await get_tree().create_timer(time).timeout
## [/codeblock]
func wait(time: float = 0, pausable := true) -> void:
	if time != 0:
		await get_tree().create_timer(time, !pausable).timeout
	else:
		await get_tree().physics_frame


## Tween an [NPC] to the specified coords (ignores all collision)
func twean_to(pos: Vector2, time: float = 1, chara: String = "P") -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(npc(chara), "global_position", Global.room.map_to_local(pos), time)
	await t.finished


func tween_linear(object: Node, property: String, to: Variant, time := 0.3) -> void:
	await tween(object, property, to, time, Tween.EASE_IN_OUT, Tween.TRANS_LINEAR)


func tween(
	object: Node,
	property: String,
	to: Variant,
	time := 0.3,
	ease_type := Tween.EASE_OUT,
	trans := Tween.TRANS_CUBIC
) -> void:
	var t := create_tween()
	t.set_ease(ease_type)
	t.set_trans(trans)
	t.tween_property(object, NodePath(property), to, time)
	await t.finished


## Make an [NPC] jump to specified coords. The height and time is relative, but keep the numbers low
func jump_to(chara: Variant, pos: Vector2, time: float = 5, height: float = 0.5) -> void:
	await jump_to_global(chara, Global.room.to_global(pos), time, height)


func jump_to_global(
	chara: Variant,
	position: Vector2,
	time: float = 5,
	height: float = 0.1,
	vibrate := true
) -> void:
	var character := resolve_chara_input(chara)
	var t: Tween = create_tween()
	var start: Vector2 = character.global_position
	var jump_distance: float = start.distance_to(position)
	var jump_height: float = jump_distance * height
	var midpoint := start.lerp(position, 0.5) + Vector2.UP * jump_height
	var jump_time := jump_distance * (time * 0.001)
	t.tween_method(
		Query.quad_bezier.bind(start, midpoint, position, character), 0.0, 1.0, jump_time
	)
	await t.finished
	if character == Global.player and vibrate:
		Controller.rumble(0, abs(height) / 3, 0.06)

	anim_done.emit()


func screen_shake(
	amount: float = 15,
	times: float = 7,
	shake_duration: float = 0.2
) -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	var dur := shake_duration / times
	var am := amount

	for i in range(0, times):
		am = am - (amount / times)
		t.tween_property(Global.camera, "offset",
		Vector2(randf_range(-am, am), randf_range(-am, am)), dur).as_relative()
		t.tween_property(Global.camera, "offset", Vector2.ZERO, dur)

	await t.finished


func node_shake(node: CanvasItem, amount := 10, repeat := randi_range(4, 8), time := 0.04) -> void:
	if not is_instance_valid(node): return
	repeat = max(repeat, 1)
	var decrease_by := maxi((amount / repeat), 2)
	var original_pos: Vector2 = node.position

	while amount > 0:
		if not is_instance_valid(node): return
		var t := create_tween().set_trans(Tween.TRANS_CUBIC)
		t.tween_property(node, "position:x", amount, time).as_relative()
		t.tween_property(node, "position:x", -amount * 2, time * 2).as_relative()
		t.tween_property(node, "position:x", amount, time).as_relative()
		await t.finished
		amount -= decrease_by
		print(amount)

	if is_instance_valid(node):
		node.position = original_pos


func heal_in_overworld(target: Actor, ab: Ability) -> void:
	var amount := (
		int(max(Query.calc_num(ab),
		target.MaxHP * ((Query.calc_num(ab) * target.Magic) * 0.02)))
	)
	target.add_health(amount)
	Global.check.emit()


func resolve_chara_input(chara: Variant) -> Node2D:
	if chara is Node2D:
		return chara

	if chara is String:
		return npc(chara)

	return null


#region Textbox Managment
func textbox_kill() -> void:
	await Textbox.kill()


func textbox_open(file: String, title: String) -> void:
	Textbox.open.call_deferred(file, title)


func portrait(img: String, redraw := true) -> void:
	if Textbox.is_open:
		await Textbox.current.portrait(img, redraw)
	elif Passive.is_open:
		await Passive.current.portrait(img, redraw)


func fade_txt_background(alpha := 0.8) -> void:
	Textbox.fade_txt_background(alpha)


func next_box(profile: String) -> void:
	if Textbox.is_open:
		Textbox.current.set_next_box(profile)
	elif Passive.is_open:
		Passive.current.set_next_box(profile)


func picture(img: String) -> void:
	if Textbox.is_open:
		await Textbox.current.set_picture(img)
	elif Passive.is_open:
		await Passive.current.set_picture(img)


func picture_clear() -> void:
	if Textbox.is_open:
		Textbox.current.picture = null
	elif Passive.is_open:
		Textbox.current.picture = null


func no_nametag() -> void:
	var current := Textbox.current

	if current != null:
		Textbox.current.no_nametag = true


func match_profile(named: String) -> BoxProfile:
	return await BoxProfile.match_profile(named)
#endregion


## Check if a flag is equal to a given value.[br]
func check_flag(flag: StringName, value := 1) -> bool:
	flag = flag.replace(" ", "_")

	if flag in flags:
		return flags.get(flag) == value

	if value == 0:
		return true
	else:
		return false


## Evaluate an expression with flags
## Additional syntax:[br]
## [code]flag + flag[/code] AND[br]
## [code]flag || flag[/code] OR[br]
## [code]flag = (Number)[/code] alternative to setting the value, useful for event triggers.[br]
## [code]day: (Number)[/code] Check if the current day is the given number.[br]
## [code]time: (Number)[/code] Check if the current time of day is the given number.[br]
func f(flag: StringName) -> bool:
	# Replace spaces with underscores, a flag cannot contain spaces
	flag = flag.replace(" ", "_")

	# "true" and "false" when left by themselves will always return that
	if flag == "true":
		return true

	if flag == "false":
		return false

	# ":" is an alias for "="

	if ":" in flag:
		return f(flag.replace(":", "="))

	# For AND expression
	if "+" in flag:
		# Recursively call this function for each expression,
		# and return false if any of them is false
		var split := flag.split("+")

		for i in split:
			if not f(i):
				return false

		return true

	# For OR expression
	if "||" in flag:
		# Recursively call this function for each expression,
		# and return true if any of them is true
		var split := flag.split("||")

		for i in split:
			if f(i):
				return true

		return false

	# For comparasion expressions
	# Splits the expression in two, split[0] for the left and split[1] for the right,
	# then replaces the expression with a string of its result (true or false).

	# For greater or equal expression
	if ">=" in flag:
		var split := flag.split(">=")
		return f(
			flag.replace(split[0] + ">=" + split[1], str(flag_int(split[0]) >= flag_int(split[1]))),
		)
	# For greater expression
	if ">" in flag:
		var split := flag.split(">")
		return f(
			flag.replace(split[0] + ">" + split[1], str(flag_int(split[0]) > flag_int(split[1]))),
		)
	# For less or equal expression
	if "<=" in flag:
		var split := flag.split("<=")
		return f(
			flag.replace(split[0] + "<=" + split[1], str(flag_int(split[0]) <= flag_int(split[1]))),
		)
	# For lesser expression
	if "<" in flag:
		var split := flag.split("<")
		return f(
			flag.replace(split[0] + "<" + split[1], str(flag_int(split[0]) < flag_int(split[1]))),
		)
	# For not equals expression
	if "!=" in flag:
		var split := flag.split("=")
		return f(
			flag.replace(
				split[0] + "!=" + split[1],
				str(flag_int(split[0]) != flag_int(split[1])),
			),
		)
	# For equals expression
	if "=" in flag:
		var split := flag.split("=")
		return f(
			flag.replace(
				split[0] + "=" + split[1],
				str(flag_int(split[0]) == flag_int(split[1])),
			),
		)

	# For NOT Expression
	# Will only run when the flag is by itself, and simply flips the result
	if flag.begins_with("!"):
		return not f(flag.replace("!", ""))

	# If just a flag is left, just return if this flag exists and is greater than 0
	if flags.has(flag) and flags.get(flag) == 1:
		return true
	else:
		return false


## Set a flag with [code]do add_flag("Example", 1)[/code]. The second parameter is optional, and is 1 by default.
func add_flag(flag: StringName, value := 1) -> bool:
	flag = flag.replace(" ", "_")

	if "=" in flag:
		var split := flag.split("=")
		return add_flag(str(split[0]), int(split[1]))

	flags.set(flag, value)
	print_rich("[color=purple]Set flag \"", flag, "\" to ", value)
	return value


func remove_flag(flag: StringName) -> void:
	if flag in flags:
		flags.erase(flag)

	print_rich("[color=purple]Removed flag \"", flag, "\"")


func pop_tutorial(id: String) -> void:
	var tutorial: TutorialPopup = (await Loader.load_res("res://UI/Tutorials/TutorialPopup.tscn")).instantiate()
	get_tree().root.add_child(tutorial)
	await tutorial.start(id)


func take_control(keep_ui := false, keep_followers := false, idle := false) -> void:
	if not is_instance_valid(Global.player):
		Global.controllable = false
		return

	var pos: Vector2= Global.player.position
	print_rich("[color=purple]Taking control")
	Global.controllable = false
	await wait()
	if not is_instance_valid(Global.player) or not is_instance_valid(Global.room):
		return

	if Global.player.dashing:
		await Global.player.stop_dash(false)
		Global.player.dashing = false

	Global.player.speed = Global.player.WALK_SPEED
	Global.player.dashdir = Vector2.ZERO
	Global.player.winding_attack = false
	Global.player.direction = Vector2.ZERO
	Hud.ui_visible = keep_ui
	Global.controllable = false

	if not keep_followers:
		for i in Global.room.followers:
			i.dont_follow = true

	await wait()
	if is_instance_valid(Global.player):
		Global.controllable = false
		Global.player.position = pos
		Global.check.emit()
		if idle:
			Global.player.state = NPC.S.IDLE
			Global.player.set_anim()


func give_control(camera_follow := false, bring_followers := true, reset_zoom := true) -> void:
	if Global.player == null:
		return

	print_rich("[color=purple]Giving control")

	if get_tree().root.has_node("Warning"):
		get_tree().root.get_node("Warning").queue_free()

	#if get_tree().root.has_node("MainMenu"):
	#get_tree().root.get_node("MainMenu").close()
	Global.player.direction = Vector2.ZERO
	Global.player.collision(true)
	Hud.ui_visible = true
	Global.controllable = true

	if camera_follow:
		Global.player.camera_follow(true)

	get_tree().paused = false

	if bring_followers:
		for i in Global.room.followers:
			i.dont_follow = false

		#Event.teleport_followers()

	if reset_zoom:
		Global.room.setup_zoom(true)

	Global.player.local_controllable = true
	Global.check.emit()


## Return the int value of a flag, or returns a nuber if given just a number
func flag_int(string: String) -> int:
	if string.is_valid_int():
		return int(string)

	if flags.has(string) and flags.get(string) is int:
		return flags.get(string)
	else:
		return 0


## Set the flag's value to max(current value, given value)
func flag_progress(stri: String, to := 1) -> void:
	if to == 0:
		remove_flag(stri)
	else:
		flags.set(stri, max(flag_int(stri), to))


## Check if the flag is equal or greater than the given value
func f_past(string: String, has_passed := 9) -> bool:
	if flag_int(string) >= has_passed:
		return true
	else:
		return false


## Show a given bubble animation above a given npc's head
func bubble(animation: String, on_npc: String) -> void:
	npc(on_npc).bubble(animation)


## Sets up a time change. Run time_transition() to properly move time
func progress_by_time(amount: int) -> void:
	to_day = get_day_progress_from_now(amount)
	to_time = get_time_progress_from_now(amount)


func get_time_progress_from_now(amount: int) -> TOD:
	var toad := time_of_day as int
	toad += amount
	toad = wrapi(toad, 1, 6)
	return toad as TOD


func get_day_progress_from_now(amount: int) -> int:
	var toad := time_of_day as int
	toad += amount

	if toad > 5:
		return day + 1
	else:
		return day


func set_time(tod: TOD) -> void:
	setup_time_changes(time_of_day, (to_day - day) * 5 + to_time)
	time_of_day = tod
	time_changed.emit()


func teleport_followers() -> void:
	#for i in Global.Area.Followers:
	#i.jump_to_player()
	Global.player.path.curve.clear_points()
	Global.player.path.curve.add_point(Global.player.position.round())
	Global.player.path.curve.add_point(Global.player.position.round())


func sequence(title: String) -> Node:
	for i in sequences.get_children():
		if i.has_method(title):
			return await i.call(title)

	OS.alert(title + " is not a valid event")
	return null


func sequence_exists(title: String) -> bool:
	for i in sequences.get_children():
		if i.has_method(title):
			return true

	return false


## Get the position of a Marker2D in the room who's name starts with "Marker" (don't include the "Marker" part)
## Use MarkerName+(x,y) to get a position relative to the marker
func get_marker_pos(title: String) -> Vector2:
	var offset := Vector2.ZERO

	if '+' in title:
		var pos_str := title.split("+")[1]
		var split := pos_str.split(',')

		if not split.is_empty():
			offset.x = split[0].to_int()

			if split.size() > 1:
				offset.y = split[1].to_int()

		title = title.split("+")[0]

	for marker in Global.room.markers:
		if marker.name.replace("Marker", "") == title:
			return marker.global_position + offset

	push_error("Failed to find marker: ", title)
	return Vector2.ZERO


func spawn(id: String, pos: Variant, animation: Variant = Direction.DOWN, z: int = Global.room.get_z(), no_shadow := false, no_collision := true) -> NPC:
	if pos is String:
		pos = Event.get_marker_pos(pos)

	var chara: NPC = (await Loader.load_res("res://rooms/components/NPC.tscn")).instantiate()
	var sprite_node := AnimatedSprite2D.new()
	chara.only_on_index = -1
	chara.add_child(sprite_node)
	sprite_node.name = "Sprite"
	sprite_node.use_parent_material = true
	chara.setup_shadow()
	if no_shadow:
		chara.shadow(false)

	var nam := id.split(":")
	var sprite := await Query.get_ov_sprites(id)

	if sprite == null:
		return null

	sprite_node.sprite_frames = sprite

	if no_collision:
		chara.collision(false)

	chara.name = nam[0]
	chara.ID = nam[0]
	chara.position = pos
	chara.z_index = z

	if Global.room.current_subroom == null:
		Global.room.add_child.call_deferred(chara)
	else:
		Global.room.current_subroom.add_child.call_deferred(chara)
		chara.position -= Global.room.current_subroom.position

	print_rich("[color=purple]Spawned: ", chara.ID)

	if animation is Direction:
		chara.look_to.call_deferred(animation)
	elif animation is String:
		if animation.length() == 1:
			chara.look_to.call_deferred(Direction.from_letter(animation))
		else:
			chara.set_anim.call_deferred(animation, false, true)

	await Event.wait()
	return chara


func no_player() -> void:
	Global.controllable = false

	if is_instance_valid(Global.player):
		Global.player.queue_free()
		for i in Global.room.followers:
			i.queue_free()
			await get_tree().physics_frame

	Hud.hide_all()


## Take the current value of to_day and to_time, and begin a proper transition to that time.
## Never run this from a dialogue file without do!
func time_transition(location := Global.room.codename()) -> void:
	if get_tree().root.has_node("Textbox"):
		get_tree().root.get_node("Textbox")._on_close()
		#await Event.wait(0.3, false)

	await Event.take_control()
	await Loader.transition()
	Loader.ungray.emit()
	await Loader.flip_time(time_of_day, to_time)
	if day != to_day:
		day = to_day
		Global.toast(Query.get_month_name(Query.get_month(day)) + " " + str(day) + " cin16")
		Loader.defeated.clear()

	set_time(to_time)
	await start_time_events(location)


## Abstraction for setting the camera zoom
func zoom(val: float, maintain := false) -> void:
	Global.camera.zoom = Vector2(val, val)

	if maintain:
		Global.room.overwrite_zoom = val


## An abstraction for setting the camera's position
## Set time to -1 to not use a tween but smoothing, set it to 0 to move it instantly
func camera_move(to: Vector2, time: float = -1, easing := Tween.EASE_IN_OUT, trans := Tween.TRANS_QUAD) -> void:
	camera_unlock()
	if time > 0:
		Global.camera.position_smoothing_enabled = false
		var t := create_tween().set_ease(easing).set_trans(trans).set_parallel()
		t.tween_property(Global.camera, "position", to, time)
		await t.finished
		Global.camera.position_smoothing_enabled = true
	elif time == 0:
		Global.camera.position_smoothing_enabled = false
		Global.camera.position = to
		Global.camera.position_smoothing_enabled = true
	else:
		Global.camera.position = to


## Move the camera by adding to its current position
func camera_move_relative(to: Vector2, time: float = -1, easing := Tween.EASE_IN_OUT, trans := Tween.TRANS_QUAD) -> void:
	await camera_move(Global.camera.position + to, time, easing, trans)


## Make the camera not follow the player
func camera_unlock() -> void:
	if is_instance_valid(Global.player):
		Global.player.camera_follow(false)


## Start any events specified for this day and time
## These could be in any Ev script
func start_time_events(location: String) -> void:
	var id := get_date_identifier()
	var map := ConfigFile.new()
	map.load("res://database/Sequences/date_event_map.cfg")

	if map.has_section(id):
		var event_script: bool = map.get_value(id, "event_script", false)
		var file: String = map.get_value(id, "file", "")
		var title: String = map.get_value(id, "title", id)

		print_rich("[color=purple]Starting date event: " + id)

		if event_script:
			await sequence(title)
		else:
			await Textbox.open(file, title)
	else:
		match location:
			"Pyrson":
				if Global.room.is_dungeon:
					await sequence("return_home_pyrson")
				else:
					await sequence("wake_home")

			"Dungeon":
				Passive.open("banter_misc", "rest_dungeon")
				give_control()

			_:
				give_control()

	Global.check.emit()
	Loader.detransition()


#TODO Make this adapt to diffrent months
## Get an id for the current date, such as "nov1_morning"
func get_date_identifier(of_day := day, time := time_of_day) -> String:
	return Query.get_mmm(Query.get_month(of_day)).to_lower() + Query.get_date_day(of_day) + "_" + Query.to_tod_text(time).to_lower()


## Run a condition script and return the number
func condition(con: String) -> int:
	if $Conditions.has_method(con):
		var res: int = $Conditions.call(con) #I'm guessing it's supposed to be an int here
		#print_rich("[color=purple]Condition "+ con+" ", res)
		return res
	else:
		push_error(con + " condition is not valid")
		return 0


## Change any parameters from the time change
func setup_time_changes(from: int, to: int) -> void:
	if f_past("eepy", 1):
		var eepy := flag_int("eepy")
		add_flag("eepy", eepy + to - from)
		if eepy >= 2 or time_of_day == TOD.MORNING:
			remove_flag("eepy")


## Checks if the current date is in reserved_date.dialogue
## Meaning you shouldn't be able to progress out of it normally
func date_is_reserved() -> bool:
	var dialogue: DialogueResource = load("res://database/Text/reserved_date.dialogue")
	var date := get_date_identifier()

	if date in dialogue.get_cues():
		return true
	else:
		return false


func get_reserved_date_dialog() -> String:
	var dialogue: DialogueResource = load("res://database/Text/reserved_date.dialogue")
	var date := get_date_identifier()
	var title: String = "default"

	if date in dialogue.get_cues():
		title = date

	return "reserved_date/" + title


func add_to_diary(what: String, in_day: int = day) -> void:
	if diary.has(in_day):
		diary.get(in_day).append(what)
	else:
		diary.set(in_day, [what])
