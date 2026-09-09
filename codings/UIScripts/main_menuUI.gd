extends CanvasLayer
var stage := "root"
var rootIndex := 1
var t: Tween
var prevRootIndex := 1
var prevPos: Vector2
var zoom: Vector2
var z: int
@onready var Cam: Camera2D = Global.camera
@onready var CamPrev: Camera2D = Global.camera.duplicate()
@onready var Fader: Control
var PrevCtrl: Control = null
var player: Mira
var duplicated := false
var focused_item: ItemData = null
var cam_follow: bool


func _ready() -> void:
	hide()
	if not ResourceLoader.exists("user://Autosave.tres"): await Loader.save()
	if not Event.f(&"HasBag") or Event.f("DisableMenus"):
		Audio.buzzer_sound()
		queue_free()
		get_tree().paused = false
		Global.controllable = true
		return

	cam_follow = Global.player.get_node("Camera2D").update_position
	await Event.take_control(true, false, false)
	if abs(Global.player.global_position - Global.camera.get_screen_center_position()).length() > 15:
		duplicated = true
		player = Global.player.duplicate()
		player.is_clone = true
		Global.room.add_child(player)
		await Event.wait()
		player.remove_light()
		player.collision_layer = 0
		player.collision_mask = 0
		player.get_node("%Shadow").hide()
		player.get_node("Flame").free()
		player.bag_anim()
	else: player = Global.player
	Cam.limit_smoothed = true
	Cam.position_smoothing_enabled = true
	Cam.process_mode = Node.PROCESS_MODE_ALWAYS
	Fader = player.get_node_or_null("Fader")
	$DottedBack.modulate = Color.TRANSPARENT
	$DescPaper.hide()
	$Confirm.show()
	$Back.show()
	$Confirm.text = "Select"
	$Back.text = "Close"
	$Party.icon = Controller.get_scheme().Select
	get_viewport().connect("gui_focus_changed", _on_focus_changed)
	if Fader == null: queue_free(); get_tree().paused = false; return
	Fader.show()
	stage = "pre_root"
	zoom = Global.camera.zoom
	prevPos = player.global_position
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.set_parallel()
	t.tween_property($Ring, "scale", Vector2.ONE, 0.6).from(Vector2(1.5, 1.5))
	t.tween_property(Cam, "offset", Vector2(0, (-15 + zoom.y)), 0.5)
	t.tween_property($Confirm, "position", Vector2(31, 742), 0.3).from(Vector2(31, 850))
	t.tween_property($Back, "position", Vector2(210, 742), 0.4).from(Vector2(210, 850))
	t.tween_property($Party, "position", Vector2(274, 28), 0.4).from(Vector2(274, -50))
	player.get_node("%Shadow").z_index = -1
	Hud.show_all()
	z = player.z_index
	player.z_index = 9

	for i in $Rail.get_children():
		i.get_child(0).position = Vector2(-30, -30)
		i.get_child(0).size.x = 64

	t.tween_property(Global.camera, "zoom", Vector2(5, 5), 0.5)
	t.tween_property(Fader, "modulate", Color(0, 0, 0, 0.6), 0.5)
	if duplicated:
		Cam.position = Global.camera.get_screen_center_position()
		t.tween_property(player, "global_position", Global.camera.get_screen_center_position(), 0.5)
		t.tween_property(Fader.material, "shader_parameter/lod", int(Global.settings.BlurEffect) * 2.5, 0.5).from(0.0)
	else: t.tween_property(Fader.material, "shader_parameter/lod", int(Global.settings.BlurEffect) * 1.0, 0.5).from(0.0)
	get_inventory()
	$Confirm.icon = Controller.get_scheme().ConfirmIcon
	$Back.icon = Controller.get_scheme().CancelIcon
	$Inventory.hide()
	#$Rail.hide()
	$AnimationPlayer.play("open")
	rootIndex = 1
	move_root()
	show()
	get_tree().paused = true
	#player.reset_speed()
	#player.bag_anim()
	stage = "root"
	await Event.wait(0.3, false)
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.set_parallel()
	$Rail.show()
	for i: PathFollow2D in $Rail.get_children():
		var button: WaveButton = i.get_child(0)
		t.tween_property(button, "size:x", 200, 0.5)
		t.tween_property(button, "position:x", -45, 0.5).as_relative()
		button.enable_waves = true

	await t.finished

var input_frame: int


func _input(event: InputEvent) -> void:
	if Controller.last_input == Global.process_frame: return
	$Confirm.icon = Controller.get_scheme().ConfirmIcon
	$Back.icon = Controller.get_scheme().CancelIcon
	$Party.icon = Controller.get_scheme().Select
	Global.controllable = false

	if input_frame == Global.process_frame: return
	match stage:
		"root":
			if Input.is_action_just_pressed("ui_up"):
				input_frame = Global.process_frame

				if rootIndex <= 0:
					$Party.grab_focus()
					rootIndex = -1
				else:
					Audio.cursor_sound()
					prevRootIndex = rootIndex
					rootIndex -= 1
					move_root()
			elif Input.is_action_just_pressed("ui_down"):
				if rootIndex == 3:
					pass
					#Audio.buzzer_sound()
				else:
					Audio.cursor_sound()
					prevRootIndex = rootIndex
					rootIndex += 1
					move_root()


func _on_focus_changed(control: Control) -> void:
	if stage == "item":
		if PrevCtrl == control or control == null:
			#Audio.buzzer_sound()
			pass
		else:
			Audio.cursor_sound()
			if control is Button: focus_item(control)

	PrevCtrl = control


func close(give_control := true) -> void:
	$AnimationPlayer.speed_scale = 2
	$AnimationPlayer.play_backwards("open")
	Global.player.get_node("DirectionMarker/Finder/Shape").disabled = false
	stage = "inactive"
	get_tree().paused = false

	if t: t.kill()
	t = create_tween()
	Global.room.get_node("Mira").set_anim()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_parallel()
	t.tween_property(Cam, "offset", Vector2(0, 0), 0.3)
	t.tween_property($Rail/JournalFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/QuestFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/OptionsFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/JournalFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/ItemFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/OptionsFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/JournalFollow/JournalButton, "size:x", 64, 0.3)
	t.tween_property($Rail/JournalFollow/JournalButton, "position:x", -30, 0.3)
	t.tween_property($Rail/ItemFollow/ItemButton, "size:x", 64, 0.3)
	t.tween_property($Rail/ItemFollow/ItemButton, "position:x", -30, 0.3)
	t.tween_property($Rail/QuestFollow/QuestButton, "size:x", 64, 0.3)
	t.tween_property($Rail/QuestFollow/QuestButton, "position:x", -30, 0.3)
	t.tween_property($Rail/OptionsFollow/OptionsButton, "size:x", 64, 0.3)
	t.tween_property($Rail/OptionsFollow/OptionsButton, "position:x", -30, 0.3)
	t.tween_property($Party, "position", Vector2(274, -80), 0.2)
	t.tween_property(player, "global_position", prevPos, 0.5)
	t.tween_property($Confirm, "position:y", 850, 0.4)
	t.tween_property($Back, "position:y", 850, 0.3)
	t.tween_property(Fader, "modulate", Color(0, 0, 0, 0), 0.5)
	t.tween_property($Ring, "scale", Vector2(1.6, 1.6), 0.3)
	t.tween_property($Ring/Glow, "modulate", Color.TRANSPARENT, 0.3)
	if Fader: t.tween_property(Fader.material, "shader_parameter/lod", 0.0, 0.5)
	Cam.position = CamPrev.position
	t.tween_property(Global.camera, "zoom", zoom, 0.3)
	if not duplicated: Global.room.setup_z(z)
	else: t.tween_property(player, "modulate", Color(0, 0, 0, 0), 0.5)
	if is_instance_valid(player):
		player.get_node("%Shadow").z_index = 0

	await t.finished
	if duplicated:
		player.free()
		Global.player = Global.room.get_child(0)

	if give_control:
		Event.give_control(cam_follow)

	Global.player.set_anim()
	Global.camera.enabled = true

	if is_instance_valid(Fader): Fader.hide()
	queue_free()


func move_root() -> void:
	var button: Button = $Rail.get_child(rootIndex).get_child(0)
	button.grab_focus()
	$Confirm.show()
	$Back.show()
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_parallel()
	t.tween_property($Rail, "position", $Rail.position, 0)
	t.tween_property($Confirm, "position:y", 741, 0.3)
	t.tween_property($Back, "position:y", 741, 0.3)
	if rootIndex == -1:
		$Party.grab_focus()
		return

	if rootIndex > prevRootIndex:
		$AnimationPlayer.stop(true)
		$AnimationPlayer.play("tick_down")
	elif rootIndex < prevRootIndex:
		$AnimationPlayer.stop(true)
		$AnimationPlayer.play("tick_up")
		t.set_trans(Tween.TRANS_BACK)

	if rootIndex == 0:
		if $Rail/JournalFollow/JournalButton.disabled:
			Audio.buzzer_sound()
			rootIndex = 1
			move_root()
			return

		t.tween_property($Base/Clip, "rotation_degrees", 19.5, 0.3)
		t.tween_property($Rail/JournalFollow/JournalButton, "scale", Vector2(1.2, 1.2), 0.3)
		t.tween_property($Rail/ItemFollow/ItemButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/QuestFollow/QuestButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/OptionsFollow/OptionsButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/JournalFollow, "progress", 540, 0.3)
		t.tween_property($Rail/ItemFollow, "progress", 660, 0.3)
		t.tween_property($Rail/QuestFollow, "progress", 770, 0.3)
		t.tween_property($Rail/OptionsFollow, "progress", 880, 0.3)
		t.tween_property($Rail/JournalFollow, "rotation_degrees", -5, 0.3)
		t.tween_property($Rail/ItemFollow, "rotation_degrees", 5, 0.3)
		t.tween_property($Rail/QuestFollow, "rotation_degrees", 25, 0.3)
		t.tween_property($Rail/OptionsFollow, "rotation_degrees", 35, 0.3)

	if rootIndex == 1:
		if prevRootIndex != 1:
			t.tween_property($Base/Clip, "rotation_degrees", 0, 0.3)

		t.tween_property($Rail/JournalFollow/JournalButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/ItemFollow/ItemButton, "scale", Vector2(1.2, 1.2), 0.3)
		t.tween_property($Rail/QuestFollow/QuestButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/OptionsFollow/OptionsButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/JournalFollow, "progress", 460, 0.3)
		t.tween_property($Rail/ItemFollow, "progress", 587, 0.3)
		t.tween_property($Rail/QuestFollow, "progress", 709, 0.3)
		t.tween_property($Rail/OptionsFollow, "progress", 817, 0.3)
		t.tween_property($Rail/JournalFollow, "rotation_degrees", -15, 0.3)
		t.tween_property($Rail/ItemFollow, "rotation_degrees", 0, 0.3)
		t.tween_property($Rail/QuestFollow, "rotation_degrees", 15, 0.3)
		t.tween_property($Rail/OptionsFollow, "rotation_degrees", 25, 0.3)

	if rootIndex == 2:
		t.tween_property($Base/Clip, "rotation_degrees", -19, 0.3)
		t.tween_property($Rail/JournalFollow/JournalButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/ItemFollow/ItemButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/QuestFollow/QuestButton, "scale", Vector2(1.2, 1.2), 0.3)
		t.tween_property($Rail/OptionsFollow/OptionsButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/JournalFollow, "progress", 380, 0.3)
		t.tween_property($Rail/ItemFollow, "progress", 490, 0.3)
		t.tween_property($Rail/QuestFollow, "progress", 590, 0.3)
		t.tween_property($Rail/OptionsFollow, "progress", 700, 0.3)
		t.tween_property($Rail/JournalFollow, "rotation_degrees", -20, 0.3)
		t.tween_property($Rail/ItemFollow, "rotation_degrees", -10, 0.3)
		t.tween_property($Rail/QuestFollow, "rotation_degrees", 0, 0.3)
		t.tween_property($Rail/OptionsFollow, "rotation_degrees", 15, 0.3)

	if rootIndex == 3:
		t.tween_property($Base/Clip, "rotation_degrees", -39, 0.3)
		t.tween_property($Rail/JournalFollow/JournalButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/ItemFollow/ItemButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/QuestFollow/QuestButton, "scale", Vector2(1, 1), 0.3)
		t.tween_property($Rail/OptionsFollow/OptionsButton, "scale", Vector2(1.2, 1.2), 0.3)
		t.tween_property($Rail/JournalFollow, "progress", 300, 0.3)
		t.tween_property($Rail/ItemFollow, "progress", 420, 0.3)
		t.tween_property($Rail/QuestFollow, "progress", 540, 0.3)
		t.tween_property($Rail/OptionsFollow, "progress", 650, 0.3)
		t.tween_property($Rail/JournalFollow, "rotation_degrees", -45, 0.3)
		t.tween_property($Rail/ItemFollow, "rotation_degrees", -25, 0.3)
		t.tween_property($Rail/QuestFollow, "rotation_degrees", -10, 0.3)
		t.tween_property($Rail/OptionsFollow, "rotation_degrees", 5, 0.3)

	await t.finished
	prevRootIndex = rootIndex


func _root() -> void:
	show()
	t.kill()
	if stage != "root":
		stage = "inactive-root"

	$Confirm.text = "Select"
	$Back.text = "Close"
	$Confirm.show()
	$Back.show()
	Hud.ui_visible = true
	$Confirm.disabled = false
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.set_parallel()
	t.tween_property($Base, "modulate", Color.WHITE, 0.5)
	t.tween_property($Rail, "modulate", Color.WHITE, 0.5)
	t.tween_property($DescPaper, "rotation_degrees", -75, 0.3)
	t.tween_property($DescPaper, "scale", Vector2(0.1, 0.1), 0.3)
	t.tween_property($DescPaper, "modulate", Color(0, 0, 0, 0), 0.2)
	for i in $Rail.get_children():
		t.tween_property(i.get_child(0), "size:x", 190, 0.3)
		t.tween_property(i.get_child(0), "position", Vector2(-90, -30), 0.3).from(Vector2(-90, -130))
		t.tween_property(i, "modulate", Color.WHITE, 0.3)
		i.z_index = 0
		i.get_child(0).toggle_mode = false

	move_root()
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property($Inventory, "size", Vector2.ZERO, 0.3)
	t.tween_property($Inventory, "modulate", Color.TRANSPARENT, 0.2)
	t.tween_property($Inventory, "position", (Vector2(803, 400)), 0.3)
	t.tween_property(Cam, "offset:x", 0, 0.8)
	t.tween_property($DottedBack, "modulate", Color.TRANSPARENT, 0.2)
	t.tween_property($Base, "position", Vector2(643, 421), 0.8)
	t.tween_property($Rail, "position", Vector2(458, 235), 0.8).from(Vector2(0, 235))
	t.tween_property($Ring, "position", Vector2(-162, -388), 0.8)
	t.tween_property($Ring, "scale", Vector2.ONE, 0.6)
	t.tween_property($Ring/Glow, "modulate", Color.WHITE, 0.6).from(Color.TRANSPARENT)
	t.tween_property($Party, "position", Vector2(274, 28), 0.4)
	$Confirm.show()
	$Back.show()
	Hud.darken(false)
	await t.finished
	if stage == "inactive-root":
		stage = "root"


func _journal() -> void:
	if stage == "inactive" or stage == "journal": return
	if rootIndex != 0:
		rootIndex = 0
		move_root()

	stage = "journal"
	Audio.confirm_sound()
	t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART).set_parallel()
	$Rail/JournalFollow/JournalButton.toggle_mode = true
	$Rail/JournalFollow/JournalButton.set_pressed_no_signal(true)
	$Rail/JournalFollow.z_index = 1
	t.tween_property($Rail/JournalFollow, "progress", 587, 0.3)
	t.tween_property($Rail/JournalFollow, "rotation_degrees", 0, 0.3)
	t.tween_property($DottedBack, "modulate", Color(0.67, 0.67, 0.62, 0.2), 0.4)
	t.tween_property($Rail/ItemFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/QuestFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/OptionsFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/ItemFollow/ItemButton, "size:x", 64, 0.5)
	t.tween_property($Rail/JournalFollow/JournalButton, "position", Vector2(-610, -100), 0.6)
	t.tween_property($Rail/QuestFollow/QuestButton, "size:x", 64, 0.5)
	t.tween_property($Rail/QuestFollow/QuestButton, "position:x", -30, 0.5)
	t.tween_property($Rail/OptionsFollow/OptionsButton, "size:x", 64, 0.5)
	t.tween_property($Rail/OptionsFollow/OptionsButton, "position:x", -30, 0.5)
	t.tween_property($Rail/JournalFollow, "progress", 587, 0.3)
	t.tween_property($Rail/ItemFollow, "progress", 587, 0.3)
	t.tween_property($Rail/QuestFollow, "progress", 587, 0.3)
	t.tween_property($Rail/OptionsFollow, "progress", 587, 0.3)
	t.tween_property(Cam, "offset:x", 100, 0.6)
	t.tween_property($Base, "position", Vector2(-500, 0), 0.6).as_relative()
	t.tween_property($Ring, "position", Vector2(-500, 0), 0.6).as_relative()
	t.tween_property($Party, "position", Vector2(-200, 28), 0.4)
	var journalui: CanvasLayer = (await Loader.load_res("res://UI/Journal/JournalUI.tscn")).instantiate()
	$Confirm.hide()
	$Back.hide()
	get_tree().root.add_child(journalui)
	Hud.hide_all()


func _item() -> void:
	if stage == "inactive": return
	rootIndex = 1
	move_root()
	Hud.ui_visible = false
	$DescPaper.show()
	$Confirm.text = "Use"
	$Back.text = "Back"
	t.kill()
	#stage="inacive"
	stage = "item"
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.set_parallel()
	$Rail/ItemFollow/ItemButton.toggle_mode = true
	$Rail/ItemFollow/ItemButton.set_pressed_no_signal(true)
	$Rail/ItemFollow.z_index = 1
	t.tween_property($Rail/ItemFollow, "progress", 587, 0.3)
	t.tween_property($Rail/ItemFollow, "rotation_degrees", 0, 0.3)
	t.tween_property($DescPaper, "rotation_degrees", 0, 0.4).from(-30)
	t.tween_property($DescPaper, "scale", Vector2(0.7, 0.7), 0.4)
	t.tween_property($DescPaper, "modulate", Color.WHITE, 0.4)
	t.tween_property($Inventory, "modulate", Color.WHITE, 0.1)
	t.tween_property($DottedBack, "modulate", Color(0.67, 0.67, 0.62, 0.2), 0.4)
	t.tween_property($Rail/JournalFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/QuestFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/OptionsFollow, "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property($Rail/JournalFollow/JournalButton, "size:x", 64, 0.5)
	t.tween_property($Rail/JournalFollow/JournalButton, "position:x", -30, 0.5)
	t.tween_property($Rail/QuestFollow/QuestButton, "size:x", 64, 0.5)
	t.tween_property($Rail/QuestFollow/QuestButton, "position:x", -30, 0.5)
	t.tween_property($Rail/OptionsFollow/OptionsButton, "size:x", 64, 0.5)
	t.tween_property($Rail/OptionsFollow/OptionsButton, "position:x", -30, 0.5)
	t.tween_property($Rail/JournalFollow, "progress", 587, 0.3)
	t.tween_property($Rail/ItemFollow, "progress", 587, 0.3)
	t.tween_property($Rail/QuestFollow, "progress", 587, 0.3)
	t.tween_property($Rail/OptionsFollow, "progress", 587, 0.3)
	t.tween_property($Party, "position", Vector2(-200, 28), 0.4)
	$Inventory.show()
	t.tween_property($Inventory, "size", Vector2(547, 549), 0.3).from(Vector2.ZERO)
	t.tween_property($Inventory, "position", Vector2(241, 123), 0.3).from(Vector2(803, 446))
	t.tween_property(Cam, "offset:x", 100, 0.6)
	t.tween_property($Base, "position", Vector2(-500, 0), 0.6).as_relative()
	t.tween_property($Ring, "position", Vector2(-500, 0), 0.6).as_relative()
	if not Item.get_inv(&"Key").is_empty():
		$Inventory/Margin/Scroller/Vbox/KeyItems.get_child(0).grab_focus()
		focus_item($Inventory/Margin/Scroller/Vbox/KeyItems.get_child(0))

	t.tween_property($Rail/ItemFollow/ItemButton, "position", Vector2(-500, -340), 0.3)
	Audio.confirm_sound()
	await t.finished
	$Rail/ItemFollow/ItemButton.position = Vector2(-500, -340)


func _quest() -> void:
	if stage == "inactive": return
	if rootIndex != 2:
		rootIndex = 2
		move_root()

	pass # Replace with function body.


func _options() -> void:
	if stage != "root": return
	if rootIndex != 3:
		rootIndex = 3
		move_root()

	stage = "options"
	Hud.ui_visible = false
	get_tree().root.add_child((await Loader.load_res("res://UI/Options/Options.tscn")).instantiate())
	Audio.confirm_sound()
	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property($Base, "modulate", Color.TRANSPARENT, 0.5)
	t.tween_property($Rail, "modulate", Color.TRANSPARENT, 0.5)
	t.tween_property($Rail, "position:x", -300, 0.5).as_relative()
	t.tween_property($Base, "position:x", -300, 0.5).as_relative()
	t.tween_property($Ring, "scale", Vector2(1.5, 1.5), 3)
	t.tween_property(Cam, "offset:x", 70, 0.5)
	t.tween_property($Party, "position", Vector2(-200, 28), 0.4)
	$Back.hide()
	$Confirm.hide()
	await t.finished
	hide()


func _on_confirm_button_down() -> void:
	if stage == "item":
		if PrevCtrl == null or not PrevCtrl.has_meta("ItemData"): return
		elif PrevCtrl is Button and PrevCtrl.get_meta("ItemData").Use != 0:
			Item.use(PrevCtrl.get_meta("ItemData"))
			Audio.confirm_sound()


func _on_back_button_down() -> void:
	if stage != "inactive": Audio.cancel_sound()
	match stage:
		"root", "inactive-root":
			close()

		"item":
			_root()

		"journal":
			_root()
			if get_tree().root.get_node_or_null("JournalUI") != null:
				get_tree().root.get_node("JournalUI").queue_free()

		"options":
			if get_tree().root.get_node_or_null("Options") == null or get_tree().root.get_node("Options").stage == "main":
				stage = "root"
				_root()
				await get_tree().create_timer(0.5).timeout
				$Back.show()
				$Confirm.show()

		"choose_member":
			if not Hud.expanded: return
			get_inventory()
			await Hud.shrink()
			await Event.wait()
			stage = "item"
			#print(Item.item.Name)
			for i in $Inventory/Margin/Scroller/Vbox/Consumables.get_children():
				if i.get_meta("ItemData") == focused_item: i.grab_focus()

			if get_viewport().gui_get_focus_owner() == null and $Inventory/Margin/Scroller/Vbox/Consumables.get_child(0):
				$Inventory/Margin/Scroller/Vbox/Consumables.get_child(0).grab_focus()
			elif get_viewport().gui_get_focus_owner() == null: $Inventory/Margin/Scroller/Vbox/KeyItems.get_child(0).grab_focus()
			Hud.ui_visible = false
			Hud.member_choosing = false


func get_inventory() -> void:
	if Item.Inventory.is_empty(): return
	Item.verify_inventory()
	var key_inv: Array[ItemData] = Item.get_inv(&"Key")
	var con_inv: Array[ItemData] = Item.get_inv(&"Con")
	var mat_inv: Array[ItemData] = Item.get_inv(&"Mat")
	var bti_inv: Array[ItemData] = Item.get_inv(&"Bti")
	var passed: Array[ItemData] = []

	if Item.get_inv(&"Con").is_empty():
		$Inventory/Margin/Scroller/Vbox/Consumables.visible = not con_inv.is_empty()
		$Inventory/Margin/Scroller/Vbox/ConLabel.visible = not con_inv.is_empty()

	if Item.get_inv(&"Mat").is_empty():
		$Inventory/Margin/Scroller/Vbox/Materials.visible = not mat_inv.is_empty()
		$Inventory/Margin/Scroller/Vbox/MatLabel.visible = not mat_inv.is_empty()

	if Item.get_inv(&"Bti").is_empty():
		$Inventory/Margin/Scroller/Vbox/BattleItems.visible = not bti_inv.is_empty()
		$Inventory/Margin/Scroller/Vbox/BtiLabel.visible = not bti_inv.is_empty()

	for i in $Inventory/Margin/Scroller/Vbox/KeyItems.get_children():
		i.queue_free()

	for i in $Inventory/Margin/Scroller/Vbox/Consumables.get_children():
		i.queue_free()

	for i in $Inventory/Margin/Scroller/Vbox/Materials.get_children():
		i.queue_free()

	for i in $Inventory/Margin/Scroller/Vbox/BattleItems.get_children():
		i.queue_free()

	for item in key_inv:
		if item in passed: continue
		passed.append(item)
		make_slot(item, $Inventory/Margin/Scroller/Vbox/KeyItems)

	for item in con_inv:
		if item in passed: continue
		passed.append(item)
		make_slot(item, $Inventory/Margin/Scroller/Vbox/Consumables)

	for item in mat_inv:
		if item in passed: continue
		passed.append(item)
		make_slot(item, $Inventory/Margin/Scroller/Vbox/Materials)

	for item in bti_inv:
		if item in passed: continue
		passed.append(item)
		make_slot(item, $Inventory/Margin/Scroller/Vbox/BattleItems)


func make_slot(item: ItemData, grid: GridContainer) -> void:
	var dub: Button = $Inventory/Item.duplicate()
	dub.icon = item.Icon
	dub.set_meta("ItemData", item)
	var item_count := Item.count(item)

	if item_count > 1:
		dub.text = str(item_count)
	else: dub.text = ""

	grid.add_child(dub)
	dub.show()


func focus_item(node: Button) -> void:
	if not node.get_parent() is GridContainer: return
	var item: ItemData = node.get_meta("ItemData")
	focused_item = item
	$DescPaper/Title.text = item.Name
	$DescPaper/Desc.text = Colorizer.colorize(item.Description)

	if node.get_parent().name == "KeyItems":
		$Inventory/Margin/Scroller.scroll_vertical = 0

	if node.get_parent().name == "BattleItems" and item.BattleEffect and item.BattleEffect.WheelColor != Color.WHITE:
		$DescPaper/Wheel.show()
		$DescPaper/Wheel.color = item.BattleEffect.WheelColor
		$DescPaper/Wheel.draw_wheel()
	else: $DescPaper/Wheel.hide()

	var item_count := Item.count(item)

	if item_count > 1:
		if item.QuantityMeansUses:
			$DescPaper/Amount.text = str(item_count) + " uses remain"
		else:
			$DescPaper/Amount.text = str(item_count) + " in bag"

		$DescPaper/Amount.show()
	else:
		$DescPaper/Amount.hide()

	if item.Use == 0:
		$Confirm.disabled = true
	elif item.Use == ItemData.U.INSPECT:
		$Confirm.disabled = false
		$Confirm.text = "Inspect"
	else:
		$Confirm.disabled = false
		$Confirm.text = "Use"

	$DescPaper/Art.texture = await item.get_artwork()


func _on_party_pressed() -> void:
	if stage == "root":
		get_viewport().gui_release_focus()
		Hud.expand()
		stage = "party"
		t = create_tween().set_parallel().set_ease(Tween.EASE_IN)
		t.tween_property($Confirm, "position:y", 900, 0.3)
		t.tween_property($Back, "position:y", 900, 0.3).set_delay(0.04)
		await t.finished
		$Confirm.hide()
		$Back.hide()


func _on_party_focus_entered() -> void:
	Audio.cursor_sound()
	t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property($Party, "scale", Vector2(1.8, 1.8), 0.3)


func _on_party_focus_exited() -> void:
	Audio.ui_sound("shrink")
	t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property($Party, "scale", Vector2(1.4, 1.4), 0.3)
