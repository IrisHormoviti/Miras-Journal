extends Control

signal ungray
signal thread_loaded

const area_spawn_path: NodePath = "/root/GameViewport/SubViewport"

var defeated: Array
var preview: Texture
var data: SaveFile
var fader: Control

var status: ResourceLoader.ThreadLoadStatus
var progress := []
var loaded_resource: String
var loading_scene := false
var load_failed := false
var loading_thread := false

var chased := false

var remembered_scene: Array[String] = []
var remembered_direction: Direction
var remembered_camera_zoom: Vector2 = Vector2(4, 4)
var traveled_pos: Vector2

@onready var t: Tween
@onready var Icon: AnimatedSprite2D = $Can/Icon
@onready var can: CanvasLayer = $Can
@onready var BAR_DOWN_POS: Vector2 = $Can/Bars/Down.position
@onready var BAR_UP_POS: Vector2 = $Can/Bars/Up.position
@onready var BAR_LEFT_POS: Vector2 = $Can/Bars/Left.position
@onready var BAR_RIGHT_POS: Vector2 = $Can/Bars/Right.position


func _ready() -> void:
	can.hide()
	Icon.global_position = Vector2(1181, 870)
	t = create_tween()
	t.tween_property(self, "position", position, 0)
	validate_save("user://Autosave.tres")
	ungray.connect(_on_ungray)


func _process(_delta: float) -> void:
	if loading_scene and !remembered_scene.is_empty():
		update_load_status(remembered_scene[0], true)

	if loading_thread:
		update_load_status(loaded_resource, false)


func update_load_status(path: String, is_scene_load: bool) -> void:
	status = ResourceLoader.load_threaded_get_status(path, progress)
	error_handle(status)

	if status == ResourceLoader.THREAD_LOAD_LOADED or (not is_scene_load and load_failed):
		if is_scene_load:
			loading_scene = false
		else:
			loading_thread = false

		thread_loaded.emit.call_deferred()


func save(filename: String = "Autosave", showicon := true) -> void:
	if not Global.player or not Global.room:
		Global.error("Cannot save right now")
		return

	print_rich("[color=green]Saving to user://" + filename + ".tres")

	if showicon:
		icon_save()

	Global.save_settings()
	Event.add_flag("day", Event.day)
	Event.add_flag("time", Event.time_of_day as int)

	data = SaveFile.new()
	data.title = filename
	data.party = Party.get_strarr()
	data.start_time = Global.first_start_time
	data.saved_time = Time.get_unix_time_from_system()
	data.play_time = Global.get_playtime()
	data.player_position = Global.player.global_position
	data.camera_index = Global.room.index
	data.complimentaries = Global.complimentaries
	data.defeated_enemies = defeated.duplicate()

	for mem in Party.members:
		data.members.append(mem.save_to_dict())

	data.version = SaveFile.VERSION
	data.flags = Event.flags.duplicate()
	data.inventory = Item.save_to_strings()
	data.diary = Event.diary
	data.room = Global.room.scene_file_path.get_file().replace(".tscn", "")

	if Global.room.current_subroom != null:
		data.room += ";" + Global.room.current_subroom.name
		data.room_name = Global.room.current_subroom.Title
	else:
		data.room_name = Global.room.title

	ResourceSaver.save(data, "user://" + filename + ".tres")
	preview = await data.preview()


func load_game(filename: String = "Autosave", sound := true, predefined := false, close_first := true, transition_after_done := true) -> void:
	if sound:
		Audio.stop_music()
		Audio.ui_sound("Load")

	if filename == "File0":
		filename = "Autosave"
	var filepath := "res://database/IncludedSaves/" + filename + ".tres" if predefined else "user://" + filename + ".tres"

	if not FileAccess.file_exists(filepath):
		await save()

	print_rich("[color=green]Loading ", filepath, "\n")

	if is_instance_valid(Global.bt):
		Global.bt.free()

	t = create_tween()
	t.tween_property(Icon, "global_position", Vector2(1181, 702), 0.2).from(Vector2(1181, 900))
	Icon.play("Load")
	await transition(Direction.CENTER)
	if get_tree().root.has_node("Initializer"):
		get_tree().root.get_node("Initializer").queue_free()

	if not validate_save(filepath):
		Loader.detransition()
		return

	Battle.prevent_battles = true
	Event.textbox_kill()
	chased = false
	data = await load_res(filepath)
	Global.start_time = Time.get_unix_time_from_system()
	Global.first_start_time = data.start_time
	Global.save_time = data.play_time
	Global.complimentaries = data.complimentaries
	defeated = data.defeated_enemies.duplicate()
	Hud.ui_visible = true
	Hud.disabled = false
	Event.flags = data.flags.duplicate()
	Event.diary = data.diary
	print_rich("[color=green]Flags loaded: ", Event.flags)
	Event.day = Event.flag_int("day")
	Event.time_of_day = Event.flag_int("time") as Event.TOD
	get_tree().paused = true

	var temp_members: Array[Actor]
	for mem_dict in data.members:
		var codename: String = mem_dict.get("codename") if mem_dict.has("codename") else ""

		if codename.is_empty(): continue

		var mem: Actor = (await Loader.load_res("res://database/Party/" + codename + ".tres")).duplicate()
		await mem.load_from_dict(mem_dict)
		temp_members.append(mem)

	if temp_members < Party.members:
		Global.toast("WARNING: This save file may have been created in an older version. Member data was missing.")
		for j in Party.members:
			var exists := false

			for i in temp_members:
				if i.codename == j.codename:
					exists = true

			if not exists:
				temp_members.append(j)

	Hud.levelup_chain.clear()
	Party.members = temp_members

	print_rich("[color=green]Current party: ", data.party)
	Party.set_to(data.party)
	for mem in Party.members:
		mem.reset_static_info()
		mem.Health = min(mem.Health, mem.MaxHP)
		mem.Aura = min(mem.Aura, mem.MaxAura)

	if !data:
		Global.error("This save file doen't exist", "WHERE FILE")

	if !data.room:
		Global.error("There's no room set in this savefile", "WHERE TF ARE YOU")

	Item.load_inventory(data.inventory)
	Item.verify_inventory()

	await travel_to(data.room, data.player_position, data.camera_index, null)

	if $/root.get_node_or_null("MainMenu"):
		$/root.get_node("MainMenu").queue_free()

	if $/root.get_node_or_null("Options"):
		$/root.get_node("Options").queue_free()

	Hud.shrink()

	if transition_after_done:
		await detransition(Direction.CENTER)
	else:
		await Event.take_control()
		dismiss_load_icon()

	preview = (await data.preview())
	print_rich("[color=green]File loaded!\n-------------------------")
	await Event.wait()

	if is_instance_valid(Global.player):
		Global.player.look_to(Vector2.DOWN)

		if (chased or Battle.in_battle) and is_instance_valid(Battle.attacker):
			print_rich("[color=green]Too close to an enemy, auto escape")
			Global.player.position = Battle.attacker.BattleSeq.EscPosition * 24
			Global.refresh()

	Battle.prevent_battles = false


func load_res(path: String) -> Resource:
	load_failed = false
	var frame := Global.process_frame

	if not Global.settings.HighResTextures:
		var low_res_path := path.replace(".png", "_low.png")

		if ResourceLoader.exists(low_res_path):
			path = low_res_path

	loaded_resource = path

	if ResourceLoader.exists(path):
		ResourceLoader.load_threaded_request(path, "")
	else:
		push_error("Resource " + path + " not found")
		return null

	loading_thread = true
	await thread_loaded

	var resource: Resource = ResourceLoader.load_threaded_get(path)

	if OS.is_debug_build():
		if Global.process_frame - frame > 1:
			print_rich("[color=#555555]\tLoaded resource: ", resource.resource_path.get_file(), "\t in ", Global.process_frame - frame, " frames")

	return resource


func travel_to_coords(sc: String, pos: Vector2 = Vector2.ZERO, camera_ind: int = 0, trans: Direction = Global.player.facing) -> void:
	travel_to(sc, Global.room.map_to_local(pos), camera_ind, trans)


## Takes the player to a specific room. Use ";" to specify a subroom, a marker or a transfer point
func travel_to(
	sc: String, pos: Vector2 = Vector2.ZERO,
	camera_ind: int = 0,
	trans: Variant = Global.player.facing if Global.player else remembered_direction,
	controllable := true
) -> void:

	if trans is String: trans = Direction.from_letter(trans)
	remembered_direction = trans

	print_rich(
		"[color=green]",
		"\nTraveling to room: ",
		sc.get_file().get_basename(),
		"\n\tCamera ID: ",
		camera_ind,
		"\n",
	)

	if t.is_running():
		await t.finished

	traveled_pos = pos

	remembered_scene.assign((sc.split(";").duplicate()))
	sc = remembered_scene[0]

	if not ".tscn" in sc:
		remembered_scene[0] = "res://rooms/" + sc + ".tscn"

	if remembered_scene[0] != "":
		ResourceLoader.load_threaded_request(remembered_scene[0])

	await transition(trans)
	Hud.hide_all(false)
	get_tree().paused = true
	status = ResourceLoader.load_threaded_get_status(remembered_scene[0], progress)
	await Event.wait()
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		await travel_done(controllable, camera_ind)
	else:
		Icon.play("Load")
		loading_scene = true
		await thread_loaded
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			await travel_done(controllable, camera_ind)


func travel_done(controllable := false, index: int = 0) -> void:
	Global.controllable = false
	get_tree().paused = true
	chased = false

	var look_dir: Direction = remembered_direction

	if is_instance_valid(Global.player):
		look_dir = Global.player.facing

	if Global.room:
		Global.room.queue_free()

	Event.npc_list.clear()
	if get_tree().root.has_node("MainMenu"):
		get_tree().root.get_node("MainMenu").queue_free()

	var area_packed: PackedScene = ResourceLoader.load_threaded_get(remembered_scene[0])

	if area_packed == null:
		return

	var area: Room = area_packed.instantiate()
	area.index = index
	get_node(area_spawn_path).add_child(area)

	await area.initialized
	Global.check.emit()

	Global.camera.position_smoothing_enabled = false
	Global.camera.position = traveled_pos

	if remembered_scene.size() > 1:
		var new_pos: Vector2 = await Global.room.go_to_subroom(remembered_scene[1], true)
		print(new_pos)
		if new_pos != Vector2.ZERO and traveled_pos == Vector2.ZERO:
			traveled_pos = new_pos

	if is_instance_valid(Global.player):
		if traveled_pos != Vector2.ZERO:
			Global.player.collision(false)
			Global.player.global_position = traveled_pos

		for i in Global.room.followers:
			i.position = traveled_pos

		if controllable and look_dir != null:
			Global.player.look_to(look_dir)

	if remembered_direction != null:
		detransition()

	Global.camera.position_smoothing_enabled = true

	if controllable:
		await Event.wait(0.3, false)
		await Hud.show_all(false, false)
		Hud.shrink(true)
		Event.give_control(false)
	else:
		Global.controllable = false

	get_tree().paused = false


func transition(dir: Direction = Global.player.facing if Global.player else remembered_direction) -> void:
	if dir == null:
		return

	remembered_direction = dir
	Global.controllable = false
	can.show()
	can.layer = 9
	$Can/Bars.modulate = Color.WHITE
	$Can/Bars.self_modulate = Color.WHITE

	if Textbox.is_open and get_tree().root.has_node("Textbox"):
		lower_layer()

	if is_instance_valid(t):
		t.kill()

	t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART).set_parallel()

	if Icon.is_playing():
		t.tween_property(Icon, "global_position", Vector2(1181, 702), 0.2)

	var letter := dir.get_letter()
	animate_bars_in(letter)

	await Event.wait(0.35, false)
	reset_bars(letter)


func animate_bars_in(letter: String) -> void:
	match letter:
		"U":
			t.tween_property($Can/Bars/Down, "position", Vector2(-200, -200), 0.3)

		"D":
			t.tween_property($Can/Bars/Up, "position", Vector2(-200, -200), 0.3)

		"R":
			t.tween_property($Can/Bars/Left, "position", Vector2(-200, -200), 0.3)

		"L":
			t.tween_property($Can/Bars/Right, "position", Vector2(-200, -200), 0.3)

		_:
			t.tween_property($Can/Bars/Down, "position", Vector2(-200, -126), 0.3)
			t.tween_property($Can/Bars/Up, "position", Vector2(-200, -200), 0.3)
			t.tween_property($Can/Bars/Left, "position", Vector2(-200, -200), 0.3)
			t.tween_property($Can/Bars/Right, "position", Vector2(-200, -200), 0.3)


func reset_bars(letter: String) -> void:
	match letter:
		"U":
			$Can/Bars/Up.position = Vector2(-200, -200)
			$Can/Bars/Down.position = BAR_DOWN_POS

		"D":
			$Can/Bars/Down.position = Vector2(-200, -200)
			$Can/Bars/Up.position = BAR_UP_POS

		"R":
			$Can/Bars/Right.position = Vector2(-200, -200)
			$Can/Bars/Left.position = BAR_LEFT_POS

		"L":
			$Can/Bars/Left.position = Vector2(-200, -200)
			$Can/Bars/Right.position = BAR_RIGHT_POS

		_:
			$Can/Bars/Up.position = Vector2(-200, -200)
			$Can/Bars/Down.position = Vector2(-200, -200)
			$Can/Bars/Right.position = Vector2(-200, -200)
			$Can/Bars/Left.position = Vector2(-200, -200)


func detransition(dir := remembered_direction) -> void:
	if dir == null:
		return

	#Engine.time_scale = 0.1

	if Global.camera: Global.camera.position_smoothing_enabled = false

	t.kill()
	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_QUART)
	$Can/Bars.self_modulate = Color.WHITE
	t.tween_property($Can/Bars/Down, "position", BAR_DOWN_POS, 0.4) #.from(Vector2(-235,-126))
	t.tween_property($Can/Bars/Up, "position", BAR_UP_POS, 0.4) #.from(Vector2(-156,-126))
	t.tween_property($Can/Bars/Left, "position", BAR_LEFT_POS, 0.4) #.from(Vector2(-200,-204))
	t.tween_property($Can/Bars/Right, "position", BAR_RIGHT_POS, 0.4) #.from(Vector2(-200,-177))
	dismiss_load_icon()
	await Event.wait(0.4, false)
	if Global.camera: Global.camera.position_smoothing_enabled = true

	Global.check.emit()
	#Global.ready_window()
	can.hide()


func restore_bars(dir: String = "") -> void:
	$Can/Bars/Down.global_position = BAR_DOWN_POS
	$Can/Bars/Up.global_position = BAR_UP_POS
	$Can/Bars/Left.global_position = BAR_LEFT_POS
	$Can/Bars/Right.global_position = BAR_RIGHT_POS


func is_in_transition() -> bool:
	return not (
			$Can/Bars/Down.global_position == BAR_DOWN_POS and
			$Can/Bars/Up.global_position == BAR_UP_POS and
			$Can/Bars/Left.global_position == BAR_LEFT_POS and
			$Can/Bars/Right.global_position == BAR_RIGHT_POS
	)


func dismiss_load_icon() -> void:
	if Icon.is_playing():
		Icon.play("Close")

	t = create_tween()
	t.tween_property($Can/Icon, "global_position", Vector2(1181, 900), 0.3)

	#InBattle = true


func icon_save() -> void:
	if Icon.is_playing():
		return

	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	can.show()
	t.tween_property(Icon, "global_position", Vector2(1181, 702), 0.2)
	#.from(Vector2(1181, 900))
	Icon.play("Save")
	await Icon.animation_finished
	t = create_tween()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property($Can/Icon, "global_position", Vector2(1181, 900), 0.3)
	await t.finished
	#can.hide()


func icon_load() -> void:
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	can.show()
	t.tween_property(Icon, "global_position", Vector2(1181, 702), 0.2)
	#.from(Vector2(1181, 900))
	Icon.play("Load")
	await ungray
	Icon.play("Close")
	t = create_tween()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property($Can/Icon, "global_position", Vector2(1181, 900), 0.3)
	await t.finished


func battle_bars(x: int, time: float = 0.5, easing := Tween.EASE_IN_OUT) -> void:
	if is_instance_valid(t):
		t.kill()

	can.layer = 1
	can.show()
	t = create_tween().set_parallel(true).set_ease(easing).set_trans(Tween.TRANS_QUART)

	match x:
		0:
			t.tween_property($Can/Bars/Down, "global_position", BAR_DOWN_POS, time)
			t.tween_property($Can/Bars/Up, "global_position", BAR_UP_POS, time)

		1:
			t.tween_property($Can/Bars/Down, "global_position", Vector2(-235, 700), time)
			t.tween_property($Can/Bars/Up, "global_position", Vector2(-156, -1050), time)
			t.tween_property($Can/Bars, "self_modulate", Color(1, 1, 1, 0.5), time)

		2:
			t.tween_property($Can/Bars/Down, "global_position", Vector2(-235, 600), time)
			t.tween_property($Can/Bars/Up, "global_position", Vector2(-156, -900), time)
			t.tween_property($Can/Bars, "self_modulate", Color(1, 1, 1, 0.7), time)

		3:
			t.tween_property($Can/Bars/Down, "global_position", Vector2(-235, 550), time)
			t.tween_property($Can/Bars/Up, "global_position", Vector2(-156, -850), time)

		4:
			t.tween_property($Can/Bars/Down, "global_position", Vector2(-235, 133), time)
			t.tween_property($Can/Bars/Up, "global_position", Vector2(-156, -400), time)
			t.tween_property($Can/Bars, "self_modulate", Color(1, 1, 1, 1), time / 2)
			

	t.tween_property($Can/Icon, "global_position", Vector2(1181, 900), 0.3)
	await t.finished


func error_handle(res: ResourceLoader.ThreadLoadStatus) -> void:
	if res == ResourceLoader.THREAD_LOAD_FAILED:
		Global.toast("A resource failed to load! \nPress F1 to check the logs.")
		load_failed = true
		loading_thread = false

		if loading_scene:
			loading_scene = false
			Global.error("The room failed to load.")


func chase_mode() -> void:
	remembered_camera_zoom = Global.camera.zoom
	chased = true


func white_fadeout(out_time: float = 7, wait_time: float = 2, in_time: float = 0.1, opacity: float = 1) -> void:
	can.show()
	fader = $Can/Bars/Left.duplicate()
	can.add_child(fader)
	fader.position = Vector2(-134, -189)
	fader.modulate = Color.TRANSPARENT
	fader.color = Color.WHITE
	var tf := create_tween()
	tf.tween_property(fader, "modulate", Color(1, 1, 1, opacity), in_time)
	await tf.finished
	await Event.wait(wait_time, false)
	can.show()
	tf = create_tween()
	tf.tween_property(fader, "modulate", Color.TRANSPARENT, out_time)
	await tf.finished
	fader.queue_free()


func gray_out(amount := 0.8, in_time := 0.3, out_time := 0, color: Color = Color.BLACK) -> void:
	can.show()
	can.layer = 3
	fader = $Can/Bars/Left.duplicate()
	can.add_child(fader)
	fader.position = Vector2(-134, -189)
	fader.modulate = Color.TRANSPARENT
	fader.color = color
	var tf := create_tween()
	tf.tween_property(fader, "modulate:a", amount, in_time)
	if out_time == 0:
		await ungray


func validate_save(savefile: String) -> bool:
	if FileAccess.file_exists(savefile):
		var file: SaveFile = load(savefile)

		if is_instance_valid(file):
			if file.version == SaveFile.VERSION or not file.version:
				return true
			else:
				# To read resource properties not in the current class, i need to load it as a config file
				print_rich("[color=green]!!! THE SAVE IS FROM AN INCOMPATIBLE VERSION")
				print_rich("[color=green]attempting to migrate from ", file.version)
				file = file.migrate()

				if file != null:
					ResourceSaver.save(file, savefile)
					return true
				else:
					Global.warning("Sorry but the stored save data is from an incompatible version, and cannot be used.\nYou might have to start a new game or use the proper version of the game.", "ERROR", ["Okay fine"])
					Global.options(1)
					return false
		else:
			Global.warning("The stored save data could not be loaded. You might have to start a new game.", "ERROR", ["Okay"])
			Global.options(1)
			return false
	else:
		return false


func flip_time(from: Event.TOD, to: Event.TOD) -> void:
	var tod: Button = $Can/TimeOfDay
	tod.modulate = Color.TRANSPARENT
	tod.scale = Vector2(0.6, 0.6)
	tod.text = Query.to_tod_text(from)
	tod.icon = await Query.to_tod_icon(from)
	tod.show()
	Hud.hide_all(false)
	var tf := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel()
	tf.tween_property(tod, "scale", Vector2(1, 1), 0.3)
	tf.tween_property(tod, "modulate", Color.WHITE, 0.3)
	get_tree().paused = false
	await tf.finished
	await Event.wait(0.3, false)
	tf = create_tween()
	tf.tween_property(tod, "scale:x", 0, 0.1)
	await tf.finished
	tod.text = Query.to_tod_text(to)
	tod.icon = await Query.to_tod_icon(to)
	tf = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tf.tween_property(tod, "scale:x", 1, 0.3)
	await Event.wait(0.6, false)
	tf = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_parallel()
	tf.tween_property(tod, "scale", Vector2(0.6, 0.6), 0.3)
	tf.tween_property(tod, "modulate", Color.TRANSPARENT, 0.3)
	await tf.finished
	tod.hide()


func lower_layer() -> void:
	can.layer = 3


func _on_ungray() -> void:
	if fader == null:
		return

	var tf := create_tween()
	tf.tween_property(fader, "modulate:a", 0, 0.3)
	await tf.finished
	if fader == null:
		return

	fader.queue_free()
