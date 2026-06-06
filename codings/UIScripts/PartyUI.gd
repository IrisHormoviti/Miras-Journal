extends Control

signal expand(i: int)
signal shrink

## Are the party boxes in the expanded state?
var Expanded: bool = false
var held := false
## Currently focused box
var focus: int = 0
## If the HUD should be visible
var UIvisible: bool = false:
	set(value):
		if UIvisible == value: return  # Prevents running if the state hasn't changed
		UIvisible = value

		# Run show_all or hide_all when this variable changes
		if not Loader.InBattle:
			if UIvisible and not Event.check_flag("DisableMenus") and not disabled:
				if Global.Settings.AutoHideHUD != 1:
					show_all()
			else:
				hide_all()
var inactive := false
## To remember if it should or shouldn't unpause the game after exiting
var WasPaused := false
## The state where a member is being chosen from the menu to use an item
var MemberChoosing := false
## Actors to level up when preform_levelups runs
var LevelupChain: Array[String] = []
## Prevent the party ui from appearing at all
var disabled := true
## A submenu (like the stats screen) is open
var submenu_opened := false
var line_to_be_used: String
var nametag_to_be_used: String
var was_controllable := false
## Where each partybox should be placed
var def_pos_partybox: Array[Vector2] = [Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2.ONE]

@onready var Partybox: VBoxContainer = %Partybox
@onready var t: Tween


func _ready() -> void:
	$CanvasLayer.hide()
	$CanvasLayer/Fade.hide()
	$CanvasLayer/Cursor.hide()
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
	UIvisible = false
	Global.check_party.connect(_check_party)
	Global.check_party.emit()


func _process(_delta: float) -> void:
	## Hide the hud when disabled
	if disabled and UIvisible: UIvisible = false

	## Run code for the party menu when expanded
	if Expanded and not submenu_opened:
		handle_ui()

	$CanvasLayer/VirtualJoystick.visible = Global.Controllable

	if not Loader.InBattle:
		if is_instance_valid(Global.Player) and Global.Controllable and Global.Player.move_frames > 0:
			if Global.Settings.AutoHideHUD == 0:
				if $IdleTimer.time_left == 0:
					show_all()
				$IdleTimer.start(3)
			if Global.Settings.AutoHideHUD == 1:
				hide_all()
				$IdleTimer.start(3)


## Shows the Partyboxes
func show_all(except_date := false, animate := true) -> void:
	if disabled: return
	if is_instance_valid(Global.Player) and Global.Settings.AutoHideHUD == 1 and Global.Player.move_frames > 0: return
	if not UIvisible: UIvisible = true
	inactive = false
	$CanvasLayer.show()
	# Animate the date UI in, except_date prevents this
	if not Loader.InBattle and not except_date:
		if animate:
			var tl := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
			tl.tween_property($CanvasLayer/CalendarBase, "position:y", 0, 0.3)
		else: $CanvasLayer/CalendarBase.position.y = 0
		$IdleTimer.start(5)

	var offset := -70
	if Loader.InBattle: offset = -60

	# Iterate through the boxes
	for i in range(0, 4):
		var box: Panel = Partybox.get_child(i)
		print(i)
		# The Leader gets position 0 since its bigger
		if i == 0:
			box.offset_transform_position.x = 0
		else:
			if animate:
				var tl := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
				tl.tween_property(box, "offset_transform_position:x", offset, 0.2)
				await Event.wait(0.03, false)
			else:
				box.offset_transform_position.x = offset
		## Animate or set the X position when in battle
		if Loader.InBattle and def_pos_partybox[i] != Vector2.ONE:
			t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
			t.tween_property(Partybox.get_child(i), "position:y", def_pos_partybox[i].y, 0.2)


## Hides the partyboxes
func hide_all(animate := true) -> void:
	if UIvisible: UIvisible = false
	if animate:
		t = create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUART)
		t.set_parallel()
		for i in range(0, 4):
			t.tween_property(Partybox.get_child(i), "offset_transform_position:x", -250, 0.3)
		t.tween_property($CanvasLayer/CalendarBase, "position:y", -150, 0.3)
	else:
		for i in range(0, 4):
			Partybox.get_child(i).offset_transform_position.x = -250


func _check_party() -> void:
	if not Global.Party: return
	if not is_instance_valid(Global.Party.Leader): return
	if Event.check_flag("DisableMenus"): disabled = true
	#$CanvasLayer/DebugText.visible = Global.Settings.DebugMode
	check_member(Global.Party.Leader, Partybox.get_node("Leader"), 0)
	for i in range(1, 4):
		if Global.Party.check_member(i):
			check_member(Global.Party.array()[i], Partybox.get_node("Member" + str(i)), i)
			Partybox.get_node("Member" + str(i)).show()
		else:
			Partybox.get_node("Member" + str(i)).hide()


func check_member(mem: Actor, node: Panel, ind: int) -> void:
	if not is_instance_valid(mem): return
	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	node.get_node("Name").text = mem.FirstName
	if UIvisible and not Expanded: node.position.y = def_pos_partybox[ind].y
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
	if Expanded:
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
	if (
		(Global.Controllable and (is_instance_valid(Global.Player) and Global.Player.get_node_or_null("%Base"))
		and "Idle" in Global.Player.sprite.animation) and not Expanded and not $CanvasLayer/TextEdit.visible
	):
		if Input.is_action_just_pressed("Options"):
			Global.options(0)
		elif Input.is_action_just_pressed("SaveManagment"):
			Global.options(1)
		elif Input.is_action_just_pressed("Manual"):
			Global.options(3)
		elif Input.is_action_just_pressed("MainMenu"):
			main_menu()
	if Input.is_action_just_pressed(Global.cancel()):
		back()
	#if Input.is_action_just_pressed("ui_accept") and MemberChoosing:
		#_on_item_preview_pressed()

	##Debug shortcuts
	if Global.Settings.DebugMode:
		if Input.is_action_just_pressed("Debug"):
			Loader.travel_to("Debug", Vector2.ZERO, 0, -1, "")
			Event.remove_flag("HideDate")
			Event.remove_flag("FlameActive")
		if Input.is_action_just_pressed("DebugT"):
			Global.passive("testbush", "greetings")
		if Input.is_action_just_pressed("DebugP"):
			Global.toast("Controllable set to " + str(!Global.Controllable))
			if Global.Controllable == true:
				Event.take_control()
			else: Event.give_control()
		if Input.is_action_just_pressed("DebugHide"):
			$CanvasLayer/DebugText.hide()
		if Input.is_action_just_pressed("DebugI"):
			Item.add_item("SmallPotion", "Con")
		if Input.is_action_just_pressed("DebugA"):
			Global.textbox("testbush", "add_to_party")
		if Input.is_action_just_pressed("DebugFlag"):
			cmd()
		if Input.is_action_just_pressed("Debug0"):
			if Engine.time_scale == 0.1: Engine.time_scale = 1
			else: Engine.time_scale = 0.1
		#Global.check_party.emit()


func darken(toggle := true) -> void:
	#print(toggle)
	t = create_tween().set_parallel()
	if toggle:
		$CanvasLayer/Fade.show()
		t.tween_property($CanvasLayer/Fade/Blur.material, "shader_parameter/lod", int(Global.Settings.BlurEffect) * 3, 0.3)
		t.tween_property($CanvasLayer/Fade, "color", Color(0, 0, 0, 0.5), 0.3)
		await t.finished
	else:
		t.tween_property($CanvasLayer/Fade, "color", Color(0, 0, 0, 0), 0.3)
		t.tween_property($CanvasLayer/Fade/Blur.material, "shader_parameter/lod", 0, 0.3)
		await t.finished
		if $CanvasLayer/Fade.color == Color(0, 0, 0, 0): $CanvasLayer/Fade.hide()
		else:
			await Event.wait(0.5)
			darken(false)


func _on_expand(open_ui := 0) -> void:
	#Engine.time_scale = 0.1
	Global.check_party.emit()
	inactive = true
	await Event.wait()
	if disabled: Global.buzzer_sound(); return
	t.kill()
	if UIvisible == false:
		await show_all(true)
	if get_tree().root.has_node("Options"): return
	if open_ui != 2: $CanvasLayer/Cursor.show()
	$CanvasLayer/Cursor.position = get_cursor_pos(0)
	#if open_ui == 0: WasPaused = false
	#else:
	WasPaused = get_tree().paused
	was_controllable = Global.Controllable
	get_tree().paused = true
	Global.Controllable = false
	$Audio.stream = preload("res://sound/SFX/expand.ogg")
	$Audio.play()
	$CanvasLayer/Cursor/ItemPreview.hide()
	%Pages.show()
	#Pages
	for page in %Pages.get_children():
		page.rotation_degrees = randf_range(-2, 2)
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.set_parallel()
	t.tween_property(Partybox, "scale", Vector2(1.5, 1.5), 0.4)
	t.tween_property($CanvasLayer/CalendarBase, "position:y", -150, 0.3)
	if open_ui == 0:
		for i in range(0, 4):
			if Query.check_member(i): get_node("%Pages/Page" + str(i)).show()
			else: get_node("%Pages/Page" + str(i)).hide()
		$CanvasLayer/Cursor/MemberOptions.show()
		$CanvasLayer/Cursor/MemberOptions/VBox/Details.icon = Global.get_controller().CommandIcon
		$CanvasLayer/Cursor/MemberOptions/VBox/Abilities.icon = Global.get_controller().ItemIcon
		$CanvasLayer/Cursor/MemberOptions/VBox/Talk.icon = Global.get_controller().ConfirmIcon
		$CanvasLayer/Cursor/MemberOptions/VBox/Talk.hide()
		$CanvasLayer/Cursor/MemberOptions.size.y = 1
		$CanvasLayer/Fade.show()
		$CanvasLayer/Back.show()
		t.tween_property($CanvasLayer/Back, "position:x", 20, 0.4)
		t.tween_property($CanvasLayer/Cursor/MemberOptions,
		"size:x", $CanvasLayer/Cursor/MemberOptions.size.x, 0.3).from(0)
		$CanvasLayer/Back.icon = Global.get_controller().CancelIcon
	else:
		$CanvasLayer/Cursor/MemberOptions.hide()
		%Pages.hide()
	if open_ui < 2:
		t = create_tween()
		t.tween_property($CanvasLayer/Cursor, "modulate", Color(1, 1, 1, 1), 0.2)
		darken()
	expand_panel(Partybox.get_node("Leader"))
	for i in range(1, 4):
		expand_panel(Partybox.get_node("Member" + str(i)), i)

	#Menu
	#if open_ui == 0:
	Global.Controllable = false
	Expanded = true
	Global.check_party.emit()
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


func _on_shrink(hurry_up := false) -> void:
	inactive = true
	Expanded = false
	Partybox.show()
	Global.check_party.emit()
	if not hurry_up:
		get_tree().paused = WasPaused
	t = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	focus = 0
	#Pages
	#$CanvasLayer/Cursor.position=CursorPosition[0]
	for i in %Pages.get_children():
		t.tween_property(i, "position", Vector2(1300, 44), 0.3)
	t.tween_property(%Pages/Page0/Render, "position", Vector2(179, 44), 0.6)
	t.tween_property($CanvasLayer/Back, "position:x", -150, 0.3)
	t.tween_property($CanvasLayer/Cursor, "modulate", Color(0, 0, 0, 0), 0.4)
	t.tween_property(Partybox, "scale", Vector2(1, 1), 0.4)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property($CanvasLayer/CalendarBase, "position:y", 0, 0.3)
	darken(false)
	if !UIvisible or disabled: hide_all(); return
	shrink_panel(Partybox.get_node("Leader"), 0, 0.0 if hurry_up else 0.4)
	for i in range(1, 4):
		shrink_panel(Partybox.get_node("Member" + str(i)), i, 0.0 if hurry_up else 0.4)
	for i in %Pages.get_children():
		i.get_node("Render").texture = null
		i.get_node("Render/Shadow").texture = null
		i.get_node("AuraDoodle").texture = null
	await t.finished
	MemberChoosing = false
	$CanvasLayer/Back.hide()
	%Pages.hide()
	$IdleTimer.start(5)
	inactive = false
	Global.check_party.emit()


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
	if mem != 0 and UIvisible:
		t.tween_property(Pan, "offset_transform_position:x", -70, time)


func handle_ui() -> void:
	if disabled or !UIvisible: Expanded = false; return
	if Input.is_action_just_pressed("ui_down"):
		if Global.Party.check_member(focus + 1):
			focus += 1
			Global.cursor_sound()
			focus_now()
			if not MemberChoosing:
				$Audio.stream = preload("res://sound/SFX/page.ogg")
			$Audio.play()
		else:
			Global.buzzer_sound()
	if Input.is_action_just_pressed("ui_up"):
		if focus - 1 != -1:
			focus -= 1
			Global.cursor_sound()
			focus_now()
			if not MemberChoosing:
				$Audio.stream = preload("res://sound/SFX/page2.ogg")
			$Audio.play()
		else:
			Global.buzzer_sound()


func focus_now() -> void:
	inactive = true
	t.kill()
	t = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property($CanvasLayer/Cursor, "position", get_cursor_pos(focus), 0.1)
	#await get_tree().create_timer(0.3).timeout
	if MemberChoosing: return
	if focus == 0: $CanvasLayer/Cursor/MemberOptions/VBox/Talk.hide()
	else: $CanvasLayer/Cursor/MemberOptions/VBox/Talk.show()
	$CanvasLayer/Cursor/MemberOptions.size.y = 1
	for i in range(0, focus):
		t.tween_property(get_node("%Pages/Page" + str(i)),
		"position", Vector2(1300, 44), 0.4 + i / 10)
		t.tween_property(get_node("%Pages/Page" + str(i) + "/Render/Shadow"),
		"modulate", Color.TRANSPARENT, 0.5)
		t.tween_property(get_node("%Pages/Page" + str(i) + "/Render"),
		"position", Vector2(-15, 0), 0.3)
		t.tween_property(get_node("%Pages/Page" + str(i) + "/Render/Shadow"),
		"position", Vector2(100, 0), 0.5)
	t.tween_property(get_node("%Pages/Page" + str(focus)),
	"position", Vector2(634, 44), 0.5)
	t.tween_property(get_node("%Pages/Page" + str(focus) + "/Render"),
	"position", Vector2(150, 130), 0.5)
	t.tween_property(get_node("%Pages/Page" + str(focus) + "/Render/Shadow"),
	"modulate", Color(1, 1, 1, 0.8), 0.5)
	t.tween_property(get_node("%Pages/Page" + str(focus) + "/Render/Shadow"),
	"position", Vector2(-35, 143), 0.5)
	for i in range(focus + 1, 4):
		t.tween_property(get_node("%Pages/Page" + str(i)),
		"position", Vector2(634, 44), 0.3 + i / 10)
		t.tween_property(get_node("%Pages/Page" + str(i) + "/Render"),
		"position", Vector2(-15, 0), 0.3)
		t.tween_property(get_node("%Pages/Page" + str(i) + "/Render/Shadow"),
		"modulate", Color.TRANSPARENT, 0.5)
		t.tween_property(get_node("%Pages/Page" + str(i) + "/Render/Shadow"),
		"position", Vector2(100, 0), 0.5)
	await t.finished
	inactive = false


func battle_state(from := false) -> void:
	if not Loader.InBattle: $CanvasLayer.hide(); return
	$CanvasLayer.show()
	$CanvasLayer/Cursor.hide()
	Partybox.scale = Vector2(1.25, 1.25)
	if from: hide_all()
	for i in range(0, 4):
		if Query.check_member(i):
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
		else: Partybox.get_child(i).hide()
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
	for member in Global.Party.array():
		var i := Global.Party.member_index(member)
		if member == Global.Bt.CurrentChar:
			t.tween_property(Partybox.get_child(i), "offset_transform_position:x", 0 if i == 0 else -70, 0.2)
			if Global.Bt.CurrentChar != Global.Party.Leader:
				t.tween_property(Partybox.get_child(i), "position:y", 20, 0.2)
		else:
			t.tween_property(Partybox.get_child(i), "offset_transform_position:x", -400, 0.2)


func check_for_levelups(mem: Actor, node: Panel) -> void:
	if mem.SkillCurve == null: return
	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	if (mem.SkillCurve != null and mem.SkillPoints < mem.skill_points_for(mem.SkillLevel)) or mem.codename in LevelupChain:
		t.tween_property(node.get_node("Level/ExpBar"), "value", mem.SkillPoints, 1)
	else:
		t.tween_property(node.get_node("Level/ExpBar"), "value", mem.skill_points_for(mem.SkillLevel), 1)
		await t.finished
		mem.SkillPoints -= mem.skill_points_for(mem.SkillLevel)
		mem.SkillPoints = max(mem.SkillPoints, 0)
		t = create_tween()
		t.tween_property(node.get_node("Level/ExpBar"), "value", 0, 0.3)
		await t.finished
		if not mem.codename in LevelupChain:
			mem.SkillLevel += 1
			LevelupChain.append(mem.codename)
			print(mem.FirstName + " grows to level ", mem.SkillLevel, ", ", mem.SkillPoints, "SP remain")
			node.get_node("Level/Number").text = str(mem.SkillLevel)
			if mem.SkillCurve != null:
				node.get_node("Level/ExpBar").max_value = mem.skill_points_for(mem.SkillLevel)
			check_for_levelups(mem, node)
		else:
			push_error("Levelup bug occured")


func make_shadow(texture: Texture2D) -> Texture2D:
	var old_image := texture.get_image()  #// Gets the image from the old texture.
	var old_size := old_image.get_size()  #// Gets the size of the image as a Vector2i
	var image := old_image.duplicate()
	#// Gets a new image, identical to the old one.
	#// Resizes the image, to one fifth of the original. Tweak this a lot depending on use, obviously.
	image.resize(old_size.x / 20, old_size.y / 20)
	#// We make a new ImageTexture (similar to any other StandardTexture2D) from our image and...
	var new_texture := ImageTexture.create_from_image(image)
	return new_texture  #// Set it as out texture.


func draw_bar(mem: Actor, node: Panel) -> void:
	var HpText: Label = node.get_node("Health/HpText")
	# Probably nothing has changed, so skip doing this
	if HpText.get_theme_color("font_color") == mem.MainColor: return
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
	node.get_node("Border1").add_theme_stylebox_override("panel", bord1.duplicate())
	var bord2: StyleBoxFlat = node.get_node("Border1/Border2").get_theme_stylebox("panel")
	bord2.border_color = mem.BoxProfile.Bord2
	node.get_node("Border1/Border2").add_theme_stylebox_override("panel", bord2.duplicate())
	var bord3: StyleBoxFlat = node.get_node("Border1/Border2/Border3").get_theme_stylebox("panel")
	bord3.border_color = mem.BoxProfile.Bord3
	node.get_node("Border1/Border2/Border3").add_theme_stylebox_override("panel", bord3.duplicate())


func choose_member() -> void:
	if not Item.get_node("ItemEffect").item: return
	_on_expand(1)
	UIvisible = true
	t = create_tween()
	$CanvasLayer/Fade.show()
	$CanvasLayer/Back.show()
	$CanvasLayer/Cursor/ItemPreview.text = (Item.get_node("ItemEffect").item.Name
	+" x" + str(Item.get_node("ItemEffect").item.Quantity))
	$CanvasLayer/Cursor/ItemPreview.icon = Item.get_node("ItemEffect").item.Icon
	$CanvasLayer/Back.icon = Global.get_controller().CancelIcon
	t.tween_property($CanvasLayer/Back, "position:x", 20, 0.3)
	t.tween_property($CanvasLayer/Cursor, "modulate", Color(1, 1, 1, 1), 0.4)
	t.tween_property($CanvasLayer/Fade/Blur.material, "shader_parameter/lod", int(Global.Settings.BlurEffect) * 3, 0.4)
	t.tween_property($CanvasLayer/Fade, "color", Color(0, 0, 0, 0.5), 0.4)
	await Event.wait(0.3, false)
	MemberChoosing = true
	$/root/MainMenu.stage = "choose_member"
	$CanvasLayer/Cursor/ItemPreview.show()
	$CanvasLayer/Cursor/ItemPreview.grab_focus()


func _on_item_preview_pressed() -> void:
	if (Item.get_node("ItemEffect").item.Quantity != 0 and
	Global.Party.get_member(focus).Health != Global.Party.get_member(focus).MaxHP):
		Item.emit_signal("return_member", (Global.Party.get_member(focus)))
	else:
		if Item.get_node("ItemEffect").item.Quantity != 0: Global.toast("HP is already maxed out")
		Global.buzzer_sound()
	$CanvasLayer/Cursor/ItemPreview.text = (Item.get_node("ItemEffect").item.Name + " x"
	+str(Item.get_node("ItemEffect").item.Quantity))


func confirm_time_passage(title: String, description: String, to_time: Event.TOD = Event.ToTime) -> bool:
	var awnser: bool = await $CanvasLayer/CalendarBase.confirm_time_passage(title, description, to_time)
	if awnser and is_instance_valid(Global.Player): await Loader.save()
	return awnser


func cmd(cmd_text := "") -> void:
	Event.add_flag("DisableMenus", false)
	PartyUI.disabled = false
	show_all()
	if not $CanvasLayer/TextEdit.visible:
		await Event.take_control(true)
		print(Event.Flags)
		$CanvasLayer/TextEdit/RichTextLabel.text = str(Event.Flags).replace(",", "\n")
		$CanvasLayer/TextEdit.show()
		$CanvasLayer/TextEdit.grab_focus()
		$CanvasLayer/TextEdit.set_deferred("text", "")
	else:
		if cmd_text.begins_with("/"):
			if cmd_text.begins_with("/clear"):
				Event.Flags.clear()
				Loader.Defeated.clear()
			elif cmd_text.begins_with("/cam"):
				Global.Player.camera_follow()
			elif cmd_text.begins_with("/day"):
				var text := cmd_text.replace("/day ", "")
				Event.Day = int(text)
			elif cmd_text.begins_with("/time"):
				var text := cmd_text.replace("/time ", "")
				Event.TimeOfDay = text.to_int() as Event.TOD
			elif cmd_text.begins_with("/comp"):
				var text := cmd_text.replace("/comp ", "")
				Global.add_complimentary(text)
			elif cmd_text.begins_with("/enrestore"):
				Loader.Defeated.clear()
			elif cmd_text.begins_with("/timetrans"):
				Event.ToDay = Event.Day
				Event.ToTime = Event.TimeOfDay
				Event.time_transition()
			elif cmd_text.begins_with("/lv"):
				Global.reset_all_members()
				var text := cmd_text.replace("/lv ", "")
				for i in Global.Party.array():
					if i != null:
						i.level_up_to(int(text))
				Global.heal_party()
				Global.check_party.emit()
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
				var day: int = Event.Day
				if text.size() > 1:
					day = int(text[1])
				Event.add_to_diary(key, day)
		elif cmd_text != "":
			var text := cmd_text
			Event.add_flag(text, !Event.check_flag(text))
			if not "=" in text:
				Global.toast("Flag \"" + text + "\" set to "
				+str(Event.flag_int(text)))
		$CanvasLayer/TextEdit.hide()
		Global.Controllable = true


func party_menu() -> void:
	if (
		Loader.InBattle == false and
		is_instance_valid(Global.Player) and
		not Global.Player.dashing and
		not MemberChoosing and
		Global.Controllable and
		not inactive
	):
		if disabled:
			Global.buzzer_sound()
			return
		if Global.Controllable:
			expand.emit()
			Global.confirm_sound()


func main_menu() -> void:
	if not Loader.InBattle and Global.Controllable and is_instance_valid(Global.Player) and not Global.Player.dashing and not Event.check_flag("DisableMenus"):
		if Global.Player.move_frames > -10:
			await Event.wait(0.3, false)
			if Global.Controllable: main_menu()
			return
		if Event.check_flag("HasBag"):
			Global.ui_sound("Menu")
			Global.Player.bag_anim()
			Global.Controllable = false
			get_tree().paused = true
			var menu: PackedScene = await Loader.load_res("res://UI/MainMenu/MainMenu.tscn")
			if get_tree().root.get_node_or_null("Options") == null:
				get_tree().root.add_child(menu.instantiate())
			else:
				get_tree().root.get_node_or_null("Options").free()
				Event.give_control()
				Global.options()
		else: Global.options()
	elif Global.Controllable: Global.buzzer_sound()


func cycle_states(chara: Actor, rect: TextureRect, reclude := true) -> void:
	if chara.States.is_empty(): rect.texture = null
	elif chara.States.size() == 1: rect.texture = chara.States[0].icon
	else:
		var index := wrapi($StateTimer.time_left, 0, chara.States.size())
		rect.texture = chara.States[index].icon
		while chara.States.size() > 1 and reclude:
			cycle_states(chara, rect, false)
			await Event.wait(0.3, false)
	rect.show()


func details() -> void:
	if Expanded and not submenu_opened:
		await Global.member_details(Global.Party.array()[focus])
		submenu_opened = true
		await Event.wait(0.2, false)
		%Pages.hide()
		$CanvasLayer/Cursor.hide()
		$CanvasLayer/Back.hide()
		Partybox.hide()


func abilities() -> void:
	if Expanded and not submenu_opened:
		await Global.member_details(Global.Party.array()[focus], 1)
		submenu_opened = true
		await Event.wait(0.2, false)
		%Pages.hide()
		$CanvasLayer/Cursor.hide()
		$CanvasLayer/Back.hide()
		Partybox.hide()


func back() -> void:
	if not MemberChoosing and Expanded and not inactive and not Loader.InBattle:
		if not submenu_opened:
			$Audio.stream = preload("res://sound/SFX/shrink.ogg")
			$Audio.play()
			shrink.emit()
			Global.cancel_sound()
			await Event.wait(0.1, false)
			Global.Controllable = was_controllable
			if get_tree().root.has_node("MainMenu"):
				get_tree().root.get_node("MainMenu").stage = "root"
				get_tree().root.get_node("MainMenu").move_root()


func close_submenu() -> void:
	Partybox.show()
	get_node("CanvasLayer/Pages/Page" + str(focus) + "/Render").show()
	$CanvasLayer/Back.show()
	%Pages.show()
	$CanvasLayer/Cursor.show()
	submenu_opened = false


func talk() -> void:
	if submenu_opened or not Expanded: return
	var dialog: DialogueResource
	dialog = load("res://database/Text/talk_" + Global.Party.array()[focus].codename.to_lower() + ".dialogue")
	if not dialog: Global.buzzer_sound(); return
	var key: String = "d" + str(Event.Day) + "_" + str(Event.flag_int(Global.Party.array()[focus].codename + "Talk"))
	if not key in dialog.get_titles(): key = "error"
	line_to_be_used = (await dialog.get_next_dialogue_line(key)).text
	nametag_to_be_used = (await dialog.get_next_dialogue_line(key)).character
	submenu_opened = true
	await Global.textbox("talk_" + Global.Party.array()[focus].codename.to_lower(), "options", true)
	close_submenu()


func preform_levelups() -> void:
	var scenepack: PackedScene = (await Loader.load_res("res://UI/LevelUp/Levelup.tscn"))
	if Global.Bt: Loader.hide_victory_stuff()
	for i in LevelupChain:
		var mem: Actor = Query.find_member(i.split(":", false)[0])
		var scene: Node = scenepack.instantiate()
		get_tree().root.add_child(scene)
		await Event.wait()
		scene.get_node("Levelup").levelup(mem)
		await scene.get_node("Levelup").closed
	LevelupChain.clear()
	show_all()


func _on_idle_timer_timeout() -> void:
	if Global.Controllable and not Loader.InBattle:
		if Global.Settings.AutoHideHUD == 0:
			hide_all()
		if Global.Settings.AutoHideHUD == 1:
			show_all()


func hit_partybox(x: int, am: int, rep: int) -> void:
	print(am, " ", rep)
	Global.node_shake(%Partybox.get_child(x), am, rep)


func _on_partybox_sort_children() -> void:
	if not Expanded:
		save_box_positions()


func _on_revive_flash_timer_timeout(source: Timer) -> void:
	var panel: Panel = source.get_parent()
	var healthbar: ProgressBar = panel.get_node("Health")
	var stylebox: StyleBoxFlat = healthbar.get_theme_stylebox("fill")
	var tf := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tf.tween_property(stylebox, "bg_color:a", 0, source.wait_time / 2)
	tf.set_ease(Tween.EASE_OUT)
	tf.tween_property(stylebox, "bg_color:a", 1, source.wait_time / 2)
