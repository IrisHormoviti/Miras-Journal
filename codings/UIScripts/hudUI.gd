extends CanvasLayer

## Are the party boxes in the expanded state?
var expanded: bool = false
var held := false
## Currently focused box
var focus: int = 0
## If the HUD should be visible
var ui_visible: bool = false:
	set(value):
		if ui_visible == value:
			return # Prevents running if the state hasn't changed

		ui_visible = value

		# Run show_all or hide_all when this variable changes
		if not Battle.in_battle:
			if ui_visible and not Event.check_flag("DisableMenus") and not disabled:
				if Global.settings.AutoHideHUD != 1:
					show_all()
			else:
				hide_all()
var inactive := false
## To remember if it should or shouldn't unpause the game after exiting
var was_paused := false
## The state where a member is being chosen from the menu to use an item
var member_choosing := false
## Actors to level up when preform_levelups runs
var levelup_chain: Array[String] = []
## Prevent the party ui from appearing at all
var disabled := true
## A submenu (like the stats screen) is open
var submenu_opened := false
var line_to_be_used: String
var nametag_to_be_used: String
var was_controllable := false
## Where each partybox should be placed
var def_pos_partybox: Array[Vector2] = [Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2.ONE]

## Used for choosing members to use something. Can be Ability or ItemDate
var member_choosing_artifact: Resource = null
var member_choosing_user: Actor

@onready var Partybox: VBoxContainer = %Partybox
@onready var t: Tween
@onready var party_menu_button: Button = %PartyMenuButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var virtual_joystick: VirtualJoystick = %VirtualJoystick
@onready var idle_timer: Timer = $IdleTimer
@onready var calendar_base: TextureRect = %CalendarBase
@onready var cursor: TextureRect = %Cursor
@onready var fader: ColorRect = %Fader
@onready var fader_blur: ColorRect = %Fader/Blur
@onready var back_button: Button = %Back


func _ready() -> void:
	fader.hide()
	cursor.hide()
	for i in range(1, 4):
		var page: TextureRect = %Pages/Page0.duplicate()
		page.name = "Page" + str(i)
		page.z_index = 3 - i
		%Pages.add_child(page)

	%Partybox/Member1.show()
	for i in range(2, 4):
		var box: Panel = %Partybox/Member1.duplicate()
		box.name = "Member" + str(i)
		Partybox.add_child(box)

	ui_visible = false
	hide_all(false)
	Global.check.connect(_check_party)
	Global.check.emit()


func _physics_process(_delta: float) -> void:
	## Hide the hud when disabled
	if disabled and ui_visible:
		ui_visible = false

	## Run code for the party menu when expanded
	if expanded and not submenu_opened:
		handle_ui()

	##TODO Take this outside _process
	if virtual_joystick:
		virtual_joystick.visible = Global.controllable and Global.player
		main_menu_button.visible = Global.controllable and Global.player

	if not Battle.in_battle:
		if is_instance_valid(Global.player) and Global.controllable and Global.player.move_frames > 0:
			if Global.settings.AutoHideHUD == 0:
				if idle_timer.time_left == 0:
					show_all()

				idle_timer.start(3)

			if Global.settings.AutoHideHUD == 1:
				hide_all()
				idle_timer.start(3)


## Shows the Partyboxes
func show_all(except_date := false, animate := true) -> void:
	if disabled:
		return

	if is_instance_valid(Global.player) and Global.settings.AutoHideHUD == 1 and Global.player.move_frames > 0:
		return

	if not ui_visible:
		ui_visible = true

	inactive = false
	# Animate the date UI in, except_date prevents this
	if not Battle.in_battle and not except_date:
		if animate:
			var tl := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
			tl.tween_property(calendar_base, "position:y", 0, 0.3)
		else:
			calendar_base.position.y = 0

		idle_timer.start(5)

	# Iterate through the boxes
	for i in range(0, 4):
		var box: Panel = Partybox.get_child(i)
		# The Leader gets position 0 since its bigger

		var box_offset := -70

		if i == 0:
			box_offset = 0
		elif Battle.in_battle:
			box_offset = -60

		if animate:
			var tl := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
			tl.tween_property(box, "offset_transform_position:x", box_offset, 0.2)
			await Event.wait(0.03, false)
		else:
			box.offset_transform_position.x = box_offset

		## Animate or set the X position when in battle
		if Battle.in_battle and def_pos_partybox[i] != Vector2.ONE:
			t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
			t.tween_property(Partybox.get_child(i), "position:y", def_pos_partybox[i].y, 0.2)


## Hides the partyboxes
func hide_all(animate := true) -> void:
	if ui_visible:
		ui_visible = false

	if animate:
		t = create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUART)
		t.set_parallel()
		for i in range(0, 4):
			t.tween_property(Partybox.get_child(i), "offset_transform_position:x", -250, 0.3)

		t.tween_property(calendar_base, "position:y", -150, 0.3)
	else:
		for i in range(0, 4):
			Partybox.get_child(i).offset_transform_position.x = -250

		calendar_base.position.y = -150


func _check_party() -> void:
	if Event.check_flag("DisableMenus"):
		disabled = true

	check_member(Party.Leader, Partybox.get_node("Leader"), 0)
	for i in range(1, 4):
		if Party.has_member_index(i):
			check_member(Party.current[i], Partybox.get_node("Member" + str(i)), i)
			Partybox.get_node("Member" + str(i)).show()
		else:
			Partybox.get_node("Member" + str(i)).hide()


func check_member(mem: Actor, node: Panel, ind: int) -> void:
	if not is_instance_valid(mem):
		return

	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	node.get_node("Name").text = mem.FirstName

	if ui_visible and not expanded:
		node.position.y = def_pos_partybox[ind].y

	var txt_color := mem.MainColor
	txt_color.v = min(txt_color.v, 0.75)
	get_node("%Pages/Page" + str(ind) + "/Label").add_theme_color_override("font_color", txt_color)
	get_node("%Pages/Page" + str(ind) + "/Label").text = mem.FirstName + " " + mem.LastName
	t.tween_property(node.get_node("Health"), "value", mem.Health, 1)
	node.get_node("Health").max_value = mem.MaxHP
	draw_bar(mem, node)
	node.get_node("Aura").max_value = mem.MaxAura
	node.get_node("Level/ExpBar").max_value = mem.skill_points_for(mem.SkillLevel)
	t.tween_property(node.get_node("Aura"), "value", mem.Aura, 1)
	node.get_node("Icon").texture = mem.PartyIcon
	cycle_states(mem, node.get_node("Icon/State"))
	node.get_node("Health/HpText").text = str(mem.Health)
	node.get_node("Aura/ApText").text = str(mem.Aura)
	node.get_node("Level/Number").text = str(mem.SkillLevel)
	var timer: Timer = node.get_node("ReviveFlashTimer") as Timer

	if mem.has_state("KnockedOut") and mem.Health > 0:
		timer.wait_time = 1 - mem.health_ratio()

		if timer.is_stopped():
			timer.start()
	else:
		timer.stop()
		node.get_node("Health").get_theme_stylebox("fill").bg_color.a = 1

	if expanded:
		# Loads render
		if get_node("%Pages/Page" + str(ind) + "/Render").texture == null and mem.RenderArtwork != null:
			get_node("%Pages/Page" + str(ind) + "/Render").texture = await Loader.load_res(mem.RenderArtwork)

		# Loads Aura doodle
		if get_node("%Pages/Page" + str(ind) + "/AuraDoodle").texture == null and mem.PartyPage != null:
			get_node("%Pages/Page" + str(ind) + "/AuraDoodle").texture = await Loader.load_res(mem.PartyPage)

		# Loads Shadow
		if get_node("%Pages/Page" + str(ind) + "/Render/Shadow").texture == null:
			get_node("%Pages/Page" + str(ind) + "/Render/Shadow").texture = await mem.RenderShadow()

	await check_for_levelups(mem, node)


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed(Controller.cancel()):
		back()


func darken(toggle := true) -> void:
	if not fader: return
	t = create_tween().set_parallel()

	if toggle:
		fader.show()
		t.tween_property(fader.get_node("Blur").material, "shader_parameter/lod", int(Global.settings.BlurEffect) * 3, 0.3)
		t.tween_property(fader, "color", Color(0, 0, 0, 0.5), 0.3)
		await t.finished
	else:
		t.tween_property(fader, "color", Color(0, 0, 0, 0), 0.3)
		t.tween_property(fader_blur.material, "shader_parameter/lod", 0, 0.3)
		await t.finished
		if fader.color == Color(0, 0, 0, 0):
			fader.hide()
		else:
			await Event.wait(0.5)
			darken(false)


func expand(open_ui := 0) -> void:
	#Engine.time_scale = 0.1
	Global.check.emit()
	inactive = true

	if disabled:
		Audio.buzzer_sound()
		return

	t.kill()
	if ui_visible == false:
		await show_all(true)

	if get_tree().root.has_node("Options"):
		return

	if open_ui != 2:
		cursor.show()

	cursor.position = get_cursor_pos(0)
	%PartyMenuButton.hide()
	#if open_ui == 0: was_paused = false
	#else:
	was_paused = get_tree().paused
	was_controllable = Global.controllable
	get_tree().paused = true
	Global.controllable = false
	$Audio.stream = preload("res://sound/SFX/expand.ogg")
	$Audio.play()
	%Pages.show()
	#Pages
	for page in %Pages.get_children():
		page.rotation_degrees = randf_range(-2, 2)

	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.set_parallel()
	t.tween_property(Partybox, "scale", Vector2(1.5, 1.5), 0.4)
	t.tween_property(%CalendarBase, "position:y", -150, 0.3)
	if open_ui == 0:
		%Cursor/ItemPreview.hide()
		for i in range(0, 4):
			if Party.has_member_index(i):
				get_node("%Pages/Page" + str(i)).show()
			else:
				get_node("%Pages/Page" + str(i)).hide()

		%Cursor/MemberOptions.show()
		%Cursor/MemberOptions/VBox/Details.icon = Controller.get_scheme().CommandIcon
		%Cursor/MemberOptions/VBox/Abilities.icon = Controller.get_scheme().ItemIcon
		%Cursor/MemberOptions/VBox/Talk.icon = Controller.get_scheme().ConfirmIcon
		%Cursor/MemberOptions/VBox/Talk.hide()
		%Cursor/MemberOptions.size.y = 1
		fader.show()
		back_button.show()
		t.tween_property(back_button, "position:x", 20, 0.4)
		t.tween_property(
			%Cursor/MemberOptions,
			"size:x",
			%Cursor/MemberOptions.size.x,
			0.3,
		).from(0)
		back_button.icon = Controller.get_scheme().CancelIcon
	else:
		%Cursor/MemberOptions.hide()
		%Pages.hide()

	if open_ui < 2:
		t = create_tween()
		t.tween_property(cursor, "modulate", Color(1, 1, 1, 1), 0.2)
		darken()
		expanded = true

	expand_panel(Partybox.get_node("Leader"))
	for i in range(1, 4):
		expand_panel(Partybox.get_node("Member" + str(i)), i)

	#Menu
	#if open_ui == 0:
	Global.controllable = false
	Global.check.emit()
	if open_ui == 0:
		await focus_now()

	inactive = false


func expand_panel(Pan: Panel, mem := 0) -> void:
	t = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	#values if not leader
	var icon_pos := Vector2(37, 50)
	var lv_pos := Vector2(140, 80)
	var hp_pos := Vector2(75, 41)
	var au_pos := Vector2(75, 46)
	var nam_pos := Vector2(81, 14)
	#values if leader
	if mem == 0:
		icon_pos = Vector2(37, 45)
		lv_pos = Vector2(140, 70)
		hp_pos = Vector2(75, 31)
		au_pos = Vector2(75, 37)
		nam_pos = Vector2(82, 3)

	t.tween_property(Pan.get_node("Icon"), "scale", Vector2(0.09, 0.09), 0.4)
	t.tween_property(Pan.get_node("Icon"), "position", icon_pos, 0.4)
	t.tween_property(Pan.get_node("Health"), "size", Vector2(110, 20), 0.4)
	t.tween_property(Pan.get_node("Aura"), "size", Vector2(110, 27), 0.4)
	Pan.get_node("Name").show()
	Pan.get_node("Level").show()
	Pan.get_node("Health/HpText").show()
	Pan.get_node("Aura/ApText").show()
	Pan.get_node("Level/ExpBar").show()
	t.tween_property(Pan.get_node("Level/ExpBar"), "modulate", Color(1, 1, 1, 1), 0.4)
	t.tween_property(Pan.get_node("Name"), "modulate", Color(1, 1, 1, 1), 0.4)
	t.tween_property(Pan.get_node("Name"), "position", nam_pos, 0.4)
	t.tween_property(Pan.get_node("Level"), "position", lv_pos, 0.4)
	t.tween_property(Pan.get_node("Health"), "position", hp_pos, 0.4)
	t.tween_property(Pan.get_node("Aura"), "position", au_pos, 0.4)
	t.tween_property(Pan.get_node("Health/HpText"), "modulate", Color(1, 1, 1, 1), 0.4)
	t.tween_property(Pan.get_node("Aura/ApText"), "modulate", Color(1, 1, 1, 1), 0.4)
	t.tween_property(Pan.get_node("Health/HpText"), "position", Vector2(115, 1), 0.4)
	t.tween_property(Pan.get_node("Aura/ApText"), "position", Vector2(115, 12), 0.4)
	t.tween_property(Pan, "offset_transform_position:x", 0, 0.4)
	await t.finished
	Partybox.queue_sort()


func shrink(hurry_up := false) -> void:
	inactive = true
	expanded = false
	Partybox.show()
	Global.check.emit()
	if not hurry_up:
		get_tree().paused = was_paused

	t = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	focus = 0
	#Pages
	#cursor.position=CursorPosition[0]

	for i in %Pages.get_children():
		t.tween_property(i, "position", Vector2(1300, 44), 0.3)

	t.tween_property(%Pages/Page0/Render, "position", Vector2(179, 44), 0.6)
	t.tween_property(back_button, "position:x", -150, 0.3)
	t.tween_property(cursor, "modulate", Color(0, 0, 0, 0), 0.4)
	t.tween_property(Partybox, "scale", Vector2(1, 1), 0.4)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(%CalendarBase, "position:y", 0, 0.3)
	%PartyMenuButton.show()
	darken(false)
	if !ui_visible or disabled:
		hide_all()
		return
	shrink_panel(Partybox.get_node("Leader"), 0, 0.0 if hurry_up else 0.4)
	for i in range(1, 4):
		shrink_panel(Partybox.get_node("Member" + str(i)), i, 0.0 if hurry_up else 0.4)
	for i in %Pages.get_children():
		i.get_node("Render").texture = null
		i.get_node("Render/Shadow").texture = null
		i.get_node("AuraDoodle").texture = null

	await t.finished
	member_choosing = false
	%Cursor/ItemPreview/AnimationPlayer.stop()
	back_button.hide()
	%Pages.hide()
	$IdleTimer.start(5)
	inactive = false
	was_paused = false
	Global.check.emit()


func shrink_panel(Pan: Panel, mem := 0, time := 0.4) -> void:
	t = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	#values if not leader
	var icon_pos := Vector2(114, 54)
	var lv_pos := Vector2(160, 76)
	var hp_pos := Vector2(159, 30)
	var au_pos := Vector2(159, 43)
	var bar_size := Vector2(54, 22)
	var nam_pos := Vector2(150, 14)
	#values if leader
	if mem == 0:
		icon_pos = Vector2(44, 44)
		lv_pos = Vector2(90, 64)
		hp_pos = Vector2(86, 16)
		au_pos = Vector2(86, 30)
		bar_size = Vector2(124, 22)
		nam_pos = Vector2(82, 3)

	t.tween_property(Pan.get_node("Icon"), "scale", Vector2(0.09, 0.09), time)
	t.tween_property(Pan.get_node("Icon"), "position", icon_pos, time)
	t.tween_property(Pan.get_node("Health"), "size", bar_size, time)
	t.tween_property(Pan.get_node("Aura"), "size", bar_size, time)
	Pan.get_node("Name").show()
	Pan.get_node("Level").show()
	Pan.get_node("Health/HpText").show()
	Pan.get_node("Aura/ApText").show()
	t.tween_property(Pan.get_node("Level/ExpBar"), "modulate", Color.TRANSPARENT, time)
	t.tween_property(Pan.get_node("Name"), "modulate", Color.TRANSPARENT, time)
	t.tween_property(Pan.get_node("Name"), "position", nam_pos, time)
	t.tween_property(Pan.get_node("Level"), "position", lv_pos, time)
	t.tween_property(Pan.get_node("Health"), "position", hp_pos, time)
	t.tween_property(Pan.get_node("Aura"), "position", au_pos, time)
	t.tween_property(Pan.get_node("Health/HpText"), "modulate", Color.TRANSPARENT, time)
	t.tween_property(Pan.get_node("Aura/ApText"), "modulate", Color.TRANSPARENT, time)
	if mem != 0 and ui_visible:
		t.tween_property(Pan, "offset_transform_position:x", -70, time)


func handle_ui() -> void:
	if disabled or !ui_visible:
		expanded = false
		return

	if Input.is_action_just_pressed("ui_down"):
		if Party.has_member_index(focus + 1):
			focus += 1
			page_down_sound()
			focus_now()
		else:
			Audio.buzzer_sound()

	if Input.is_action_just_pressed("ui_up"):
		if focus - 1 != -1:
			focus -= 1
			page_up_sound()
			focus_now()
		else:
			Audio.buzzer_sound()


func page_up_sound() -> void:
	Audio.cursor_sound()
	if not member_choosing:
		$Audio.stream = await Loader.load_res("res://sound/SFX/page2.ogg")

	$Audio.play()


func page_down_sound() -> void:
	Audio.cursor_sound()
	if not member_choosing:
		$Audio.stream = await Loader.load_res("res://sound/SFX/page.ogg")

	$Audio.play()


func focus_now() -> void:
	inactive = true
	t.kill()
	t = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(cursor, "position", get_cursor_pos(focus), 0.1)
	#await get_tree().create_timer(0.3).timeout
	if member_choosing:
		return

	if focus == 0:
		%Cursor/MemberOptions/VBox/Talk.hide()
	else:
		%Cursor/MemberOptions/VBox/Talk.show()

	%Cursor/MemberOptions.size.y = 1

	for i in range(0, focus):
		t.tween_property(
			get_node("%Pages/Page" + str(i)),
			"position",
			Vector2(1300, 44),
			0.4 + i / 10,
		)
		t.tween_property(
			get_node("%Pages/Page" + str(i) + "/Render/Shadow"),
			"modulate",
			Color.TRANSPARENT,
			0.5,
		)
		t.tween_property(
			get_node("%Pages/Page" + str(i) + "/Render"),
			"position",
			Vector2(-15, 0),
			0.3,
		)
		t.tween_property(
			get_node("%Pages/Page" + str(i) + "/Render/Shadow"),
			"position",
			Vector2(100, 0),
			0.5,
		)
	t.tween_property(
		get_node("%Pages/Page" + str(focus)),
		"position",
		Vector2(634, 44),
		0.5,
	)
	t.tween_property(
		get_node("%Pages/Page" + str(focus) + "/Render"),
		"position",
		Vector2(150, 130),
		0.5,
	)
	t.tween_property(
		get_node("%Pages/Page" + str(focus) + "/Render/Shadow"),
		"modulate",
		Color(1, 1, 1, 0.8),
		0.5,
	)
	t.tween_property(
		get_node("%Pages/Page" + str(focus) + "/Render/Shadow"),
		"position",
		Vector2(-35, 143),
		0.5,
	)
	for i in range(focus + 1, 4):
		t.tween_property(
			get_node("%Pages/Page" + str(i)),
			"position",
			Vector2(634, 44),
			0.3 + i / 10,
		)
		t.tween_property(
			get_node("%Pages/Page" + str(i) + "/Render"),
			"position",
			Vector2(-15, 0),
			0.3,
		)
		t.tween_property(
			get_node("%Pages/Page" + str(i) + "/Render/Shadow"),
			"modulate",
			Color.TRANSPARENT,
			0.5,
		)
		t.tween_property(
			get_node("%Pages/Page" + str(i) + "/Render/Shadow"),
			"position",
			Vector2(100, 0),
			0.5,
		)
	await t.finished
	inactive = false


func battle_state(from := false) -> void:
	if not Battle.in_battle:
		return

	cursor.hide()
	Partybox.scale = Vector2(1.25, 1.25)

	if from:
		hide_all()

	for i in range(0, 4):
		if Party.has_member_index(i):
			Partybox.get_child(i).get_node("Name").show()
			Partybox.get_child(i).get_node("Level").show()
			Partybox.get_child(i).get_node("Icon").scale = Vector2(0.09, 0.09)
			Partybox.get_child(i).get_node("Icon").position = Vector2(37, 45) if i == 0 else Vector2(97, 52)
			Partybox.get_child(i).get_node("Health").size = Vector2(110 if i == 0 else 60, 20)
			Partybox.get_child(i).get_node("Health").position = Vector2(75, 31) if i == 0 else Vector2(135, 40)
			Partybox.get_child(i).get_node("Aura").size = Vector2(110 if i == 0 else 60, 27)
			Partybox.get_child(i).get_node("Aura").position = Vector2(75, 37) if i == 0 else Vector2(135, 43)
			Partybox.get_child(i).get_node("Health/HpText").modulate = Color.WHITE
			Partybox.get_child(i).get_node("Level/ExpBar").modulate = Color.WHITE if i == 0 else Color.TRANSPARENT
			Partybox.get_child(i).get_node("Name").modulate = Color.WHITE
			Partybox.get_child(i).get_node("Aura/ApText").modulate = Color.WHITE
			Partybox.get_child(i).get_node("Level").position = Vector2(140, 70) if i == 0 else Vector2(140, 78)

			if i != 0:
				Partybox.get_child(i).size.y = 100
				Partybox.get_child(i).get_node("Name").position.x = 140
				Partybox.get_child(i).get_node("Health/HpText").position.x = 64
				Partybox.get_child(i).get_node("Aura/ApText").position.x = 64

			t = create_tween()
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_QUART)
			t.set_parallel()
			t.tween_property(Partybox.get_child(i), "offset_transform_position:x", 0 if i == 0 else -60, 0.3)
		else:
			Partybox.get_child(i).hide()

	for i in range(0, 4):
		if def_pos_partybox[i] != Vector2.ONE:
			t.tween_property(Partybox.get_child(i), "position:y", def_pos_partybox[i].y, 0.2)


func save_box_positions() -> void:
	for i in range(0, 4):
		var box: Control = Partybox.get_child(i)

		if i == 0 or box.position.y > 100:
			def_pos_partybox[i] = box.position


func get_cursor_pos(index: int) -> Vector2:
	return Vector2(400, %Partybox.get_child(index).global_position.y + 50)


func _on_battle_ui_root() -> void:
	battle_state()


func only_current() -> void:
	t = create_tween()
	t.set_parallel(true)
	for member: Actor in Party.current:
		var i: int = Party.member_index(member)

		if member == Global.bt.CurrentChar:
			t.tween_property(Partybox.get_child(i), "offset_transform_position:x", 0 if i == 0 else -70, 0.2)

			if Global.bt.CurrentChar != Party.Leader:
				t.tween_property(Partybox.get_child(i), "position:y", 20, 0.2)
		else:
			t.tween_property(Partybox.get_child(i), "offset_transform_position:x", -400, 0.2)


func check_for_levelups(mem: Actor, node: Panel) -> void:
	if mem.SkillCurve == null:
		return

	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	if (mem.SkillCurve != null and mem.SkillPoints < mem.skill_points_for(mem.SkillLevel)) or mem.codename in levelup_chain:
		t.tween_property(node.get_node("Level/ExpBar"), "value", mem.SkillPoints, 1)
	else:
		t.tween_property(node.get_node("Level/ExpBar"), "value", mem.skill_points_for(mem.SkillLevel), 1)
		await t.finished
		mem.SkillPoints -= mem.skill_points_for(mem.SkillLevel)
		mem.SkillPoints = max(mem.SkillPoints, 0)
		t = create_tween()
		t.tween_property(node.get_node("Level/ExpBar"), "value", 0, 0.3)
		await t.finished
		if not mem.codename in levelup_chain:
			mem.SkillLevel += 1
			levelup_chain.append(mem.codename)
			print(mem.FirstName + " grows to level ", mem.SkillLevel, ", ", mem.SkillPoints, "SP remain")
			node.get_node("Level/Number").text = str(mem.SkillLevel)

			if mem.SkillCurve != null:
				node.get_node("Level/ExpBar").max_value = mem.skill_points_for(mem.SkillLevel)

			check_for_levelups(mem, node)


func make_shadow(texture: Texture2D) -> Texture2D:
	var old_image := texture.get_image() #// Gets the image from the old texture.
	var old_size := old_image.get_size() #// Gets the size of the image as a Vector2i
	var image := old_image.duplicate()
	#// Gets a new image, identical to the old one.
	#// Resizes the image, to one fifth of the original. Tweak this a lot depending on use, obviously.
	image.resize(old_size.x / 20, old_size.y / 20)
	#// We make a new ImageTexture (similar to any other StandardTexture2D) from our image and...
	var new_texture := ImageTexture.create_from_image(image)
	return new_texture #// Set it as out texture.


func draw_bar(mem: Actor, node: Panel) -> void:
	var HpText: Label = node.get_node("Health/HpText")
	# Probably nothing has changed, so skip doing this
	if HpText.get_theme_color("font_color") == mem.MainColor:
		return
	HpText.add_theme_color_override("font_color", mem.AuraDefault if mem.has_state("AuraOverwrite") else mem.MainColor)

	var ApText: Label = node.get_node("Aura/ApText")
	ApText.add_theme_color_override("font_color", mem.SecondaryColor)

	# Health
	var hbox: StyleBoxFlat = node.get_node("Health").get_theme_stylebox("fill")
	var alpha := hbox.bg_color.a
	hbox.bg_color = mem.AuraDefault if mem.has_state("AuraOverwrite") else mem.MainColor
	hbox.bg_color.a = alpha
	node.get_node("Health").add_theme_stylebox_override("fill", hbox.duplicate())

	# Aura
	var abox: StyleBoxFlat = node.get_node("Aura").get_theme_stylebox("fill")
	abox.bg_color = mem.SecondaryColor
	node.get_node("Aura").add_theme_stylebox_override("fill", abox.duplicate())
	var bord1: StyleBoxFlat = node.get_node("Border1").get_theme_stylebox("panel")
	bord1.border_color = mem.MainColor

	# Borders
	if mem.CharacterBoxProfile:
		node.get_node("Border1").add_theme_stylebox_override("panel", bord1.duplicate())
		var bord2: StyleBoxFlat = node.get_node("Border1/Border2").get_theme_stylebox("panel")
		bord2.border_color = mem.CharacterBoxProfile.Bord2
		node.get_node("Border1/Border2").add_theme_stylebox_override("panel", bord2.duplicate())
		var bord3: StyleBoxFlat = node.get_node("Border1/Border2/Border3").get_theme_stylebox("panel")
		bord3.border_color = mem.CharacterBoxProfile.Bord3
		node.get_node("Border1/Border2/Border3").add_theme_stylebox_override("panel", bord3.duplicate())


func choose_member(artifact: Resource, user: Actor = Party.Leader) -> void:
	if artifact is ItemData:
		if not artifact:
			return

		%Cursor/ItemPreview.text = (artifact.Name+ " x" + str(Item.count(artifact)))
		%Cursor/ItemPreview.icon = artifact.Icon
		$/root/MainMenu.stage = "choose_member"
	elif artifact is Ability:
		%Cursor/ItemPreview.text = artifact.name
		%Cursor/ItemPreview.icon = artifact.Icon
	else:
		push_error("Invalid use of choose_member")
		return

	member_choosing_artifact = artifact
	member_choosing_user = user

	if not expanded:
		expand(1)

	ui_visible = true
	t = create_tween()
	fader.show()
	back_button.show()

	back_button.icon = Controller.get_scheme().CancelIcon
	t.tween_property(back_button, "position:x", 20, 0.3)
	t.tween_property(cursor, "modulate", Color(1, 1, 1, 1), 0.4)
	t.tween_property(fader.get_node("Blur").material, "shader_parameter/lod", int(Global.settings.BlurEffect) * 3, 0.4)
	t.tween_property(fader, "color", Color(0, 0, 0, 0.5), 0.4)
	%Cursor/ItemPreview/AnimationPlayer.play(&"hover")
	%Cursor/ItemPreview.show()
	%Cursor/MemberOptions.hide()
	await Event.wait(0.3, false)
	member_choosing = true
	%Cursor/ItemPreview.grab_focus()


func _on_item_preview_pressed() -> void:
	if member_choosing_artifact is ItemData:
		if Item.count(member_choosing_artifact) != 0:
			if Party.current[focus].Health >= Party.current[focus].MaxHP:
				Global.toast("HP is already maxed out")
				Audio.buzzer_sound()

			Item.emit_signal("return_member", (Party.current[focus]))
		else:
			Audio.buzzer_sound()
			Global.toast("No more of this item is left")

		%Cursor/ItemPreview.text = (member_choosing_artifact.Name + " x" + str(Item.count(member_choosing_artifact)))

	if member_choosing_artifact is Ability:
		if Party.current[focus].Health >= Party.current[focus].MaxHP:
			Global.toast("HP is already maxed out")
			Audio.buzzer_sound()
		else:
			Event.heal_in_overworld(Party.current[focus], member_choosing_artifact)
			member_choosing_user.add_aura(-member_choosing_artifact.AuraCost)
			back()


func confirm_time_passage(title: String, description: String, to_time: Event.TOD = Event.to_time) -> bool:
	var awnser: bool = await %CalendarBase.confirm_time_passage(title, description, to_time)

	if awnser and is_instance_valid(Global.player):
		await Loader.save()

	return awnser


func cmd(cmd_text := "") -> void:
	Event.add_flag("DisableMenus", false)
	Hud.disabled = false
	show_all()
	if not %DebugTextEdit.visible:
		await Event.take_control(true)
		print(Event.flags)
		%DebugTextEdit/RichTextLabel.text = str(Event.flags).replace(",", "\n")
		%DebugTextEdit.show()
		%DebugTextEdit.grab_focus()
		%DebugTextEdit.set_deferred("text", "")
	else:
		if cmd_text.begins_with("/"):
			if cmd_text.begins_with("/clear"):
				Event.flags.clear()
				Loader.defeated.clear()
			elif cmd_text.begins_with("/cam"):
				Global.player.camera_follow()
			elif cmd_text.begins_with("/day"):
				var text := cmd_text.replace("/day ", "")
				Event.day = int(text)
			elif cmd_text.begins_with("/time"):
				var text := cmd_text.replace("/time ", "")
				Event.time_of_day = text.to_int() as Event.TOD
			elif cmd_text.begins_with("/comp"):
				var text := cmd_text.replace("/comp ", "")
				Global.add_complimentary(text)
			elif cmd_text.begins_with("/enrestore"):
				Loader.defeated.clear()
			elif cmd_text.begins_with("/giant"):
				Global.player.scale *= 2
			elif cmd_text.begins_with("/timetrans"):
				Event.to_day = Event.day
				Event.to_time = Event.time_of_day
				Event.time_transition()
			elif cmd_text.begins_with("/lv"):
				Party.reset_all_members()
				var text := cmd_text.replace("/lv ", "")

				for i: Actor in Party.current:
					if i != null:
						i.level_up_to(int(text))

				Global.heal_party()
				Global.check.emit()
			elif cmd_text.begins_with("/item"):
				var text: String = cmd_text.replace("/item ", "")
				var split := text.split(":")

				if split.size() < 2:
					Global.toast("Item type needed")
					return

				Item.add_item(split[0], split[1])
			elif cmd_text.begins_with("/itemrm"):
				var text: String = cmd_text.replace("/itemrm ", "")
				var split := text.split(":")

				if split.size() < 2:
					Global.toast("Item type needed")
					return

				Item.remove_item(split[0], split[1])
			elif cmd_text.begins_with("/diaryadd"):
				var text := cmd_text.replace("/diaryadd ", "").split('>')
				var key: String = text[0]
				var day: int = Event.day

				if text.size() > 1:
					day = int(text[1])

				Event.add_to_diary(key, day)
		elif cmd_text != "":
			var text := cmd_text
			Event.add_flag(text, !Event.check_flag(text))
			if not "=" in text:
				Global.toast(
					"Flag \"" + text + "\" set to "
					+ str(Event.flag_int(text)),
				)
		%DebugTextEdit.hide()
		Global.controllable = true


func party_menu() -> void:
	if (
			not Battle.in_battle and
			is_instance_valid(Global.player) and
			not Global.player.dashing and
			not member_choosing and
			Global.controllable and
			not inactive
	):
		if disabled:
			Audio.buzzer_sound()
			return

		if Global.controllable:
			expand()
			Audio.confirm_sound()


func main_menu() -> void:
	if not Battle.in_battle and Global.controllable and is_instance_valid(Global.player) and not Global.player.dashing and not Event.check_flag("DisableMenus"):
		if Global.player.move_frames > -10:
			await Event.wait(0.3, false)
			if Global.controllable:
				main_menu()

			return

		if Event.check_flag("HasBag"):
			Audio.ui_sound("Menu")
			Global.player.bag_anim()
			Global.controllable = false
			get_tree().paused = true
			var menu: PackedScene = await Loader.load_res("res://UI/MainMenu/MainMenu.tscn")

			if get_tree().root.get_node_or_null("Options") == null:
				get_tree().root.add_child(menu.instantiate())
			else:
				get_tree().root.get_node_or_null("Options").free()
				Event.give_control()
				Global.options()
		else:
			Global.options()
	elif Global.controllable:
		Audio.buzzer_sound()


func cycle_states(chara: Actor, rect: TextureRect, reclude := true) -> void:
	if chara.States.is_empty():
		rect.texture = null
	elif chara.States.size() == 1:
		rect.texture = chara.States[0].icon
	else:
		var index := wrapi($StateTimer.time_left, 0, chara.States.size())
		rect.texture = chara.States[index].icon

		while chara.States.size() > 1 and reclude:
			cycle_states(chara, rect, false)
			await Event.wait(0.3, false)

	rect.show()


func details() -> void:
	if expanded and not submenu_opened:
		await Global.member_details(Party.current[focus])
		submenu_opened = true
		await Event.wait(0.2, false)
		%Pages.hide()
		cursor.hide()
		back_button.hide()
		Partybox.hide()


func abilities() -> void:
	if expanded and not submenu_opened:
		await Global.member_details(Party.current[focus], 1)
		submenu_opened = true
		await Event.wait(0.2, false)
		%Pages.hide()
		cursor.hide()
		back_button.hide()
		Partybox.hide()


func back() -> void:
	if member_choosing and expanded and not (
		get_tree().root.has_node("MainMenu") and get_tree().root.get_node("MainMenu").stage == "choose_member"
	):
		%Cursor/ItemPreview.hide()
		%Cursor/ItemPreview/AnimationPlayer.stop()
		%Cursor/MemberOptions.show()
		member_choosing = false
		Audio.confirm_sound()
		focus = Party.current.find(member_choosing_user)
		focus_now()
	elif not member_choosing and expanded and not inactive and not Battle.in_battle:
		if not submenu_opened:
			$Audio.stream = await Loader.load_res("res://sound/SFX/shrink.ogg")
			$Audio.play()
			shrink()
			Audio.cancel_sound()
			await Event.wait(0.1, false)
			Global.controllable = was_controllable

			if get_tree().root.has_node("MainMenu"):
				get_tree().root.get_node("MainMenu").stage = "root"
				get_tree().root.get_node("MainMenu").move_root()


func close_submenu() -> void:
	Partybox.show()
	get_node("%Pages/Page" + str(focus) + "/Render").show()
	back_button.show()
	%Pages.show()
	cursor.show()
	submenu_opened = false


func talk() -> void:
	if submenu_opened or not expanded:
		return

	var dialog: DialogueResource
	dialog = load("res://database/Text/talk_" + Party.current[focus].codename.to_lower() + ".dialogue")

	if not dialog:
		Audio.buzzer_sound()
		return

	var key: String = "d" + str(Event.day) + "_" + str(Event.flag_int(Party.current[focus].codename + "Talk"))

	if not key in dialog.get_cues():
		key = "error"

	line_to_be_used = (await dialog.get_next_dialogue_line(key)).text
	nametag_to_be_used = (await dialog.get_next_dialogue_line(key)).character
	submenu_opened = true
	await Textbox.open("talk_" + Party.current[focus].codename.to_lower(), "options", true)
	close_submenu()


func preform_levelups() -> void:
	var scenepack: PackedScene = (await Loader.load_res("res://UI/LevelUp/Levelup.tscn"))

	if Global.bt:
		Battle.current.hide_victory_stuff()

	for i in levelup_chain:
		var mem: Actor = Party.get_member(i.split(":", false)[0])
		var scene: Node = scenepack.instantiate()
		get_tree().root.add_child(scene)
		await Event.wait()
		scene.get_node("Levelup").levelup(mem)
		await scene.get_node("Levelup").closed

	levelup_chain.clear()
	show_all()


func _on_idle_timer_timeout() -> void:
	if Global.controllable and not Battle.in_battle:
		if Global.settings.AutoHideHUD == 0:
			hide_all()

		if Global.settings.AutoHideHUD == 1:
			show_all()


func hit_partybox(x: int, am: int, rep: int) -> void:
	prints("hit_partybox", x, am, rep)
	Event.node_shake(%Partybox.get_child(x), am, rep)


func _on_partybox_sort_children() -> void:
	if not expanded:
		save_box_positions()


func _on_revive_flash_timer_timeout(source: Timer) -> void:
	var panel: Panel = source.get_parent()
	var healthbar: ProgressBar = panel.get_node("Health")
	var stylebox: StyleBoxFlat = healthbar.get_theme_stylebox("fill")
	var tf := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tf.tween_property(stylebox, "bg_color:a", 0, source.wait_time / 2)
	tf.set_ease(Tween.EASE_OUT)
	tf.tween_property(stylebox, "bg_color:a", 1, source.wait_time / 2)


func _on_virtual_joystick_flicked(input_vector: Vector2) -> void:
	if input_vector.length() >= 1:
		Input.action_press("Dash")
		await virtual_joystick.released
		Input.action_release("Dash")


func _on_main_menu_button_pressed() -> void:
	main_menu()


func _on_partybox_focus_entered(source: Control) -> void:
	var index := source.get_index()

	if expanded and index != focus:
		if index > focus:
			page_down_sound()
		else:
			page_up_sound()

		focus = index
		focus_now()
