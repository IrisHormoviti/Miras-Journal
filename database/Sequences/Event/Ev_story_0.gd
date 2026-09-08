extends Node


func new_game() -> void:
	Global.first_start_time = Time.get_unix_time_from_system()

	# Hide any UI
	if get_tree().root.has_node("/root/Textbox"): $"/root/Textbox"._on_close()
	if get_tree().root.has_node("/root/Initializer"): $"/root/Initializer".queue_free()
	Hud.hide_all()
	# Initial flags
	Event.flags.clear()
	Event.add_flag("Started")
	Event.add_flag("HasBag", false)
	Event.add_flag("DisableMenus", true)
	Event.add_flag("HideDate", true)
	Event.add_flag("DisableVeinet")
	Event.add_flag("time", Event.TOD.NIGHT)
	Event.add_flag("day", 0)
	Event.day = 0
	Event.time_of_day = Event.TOD.NIGHT
	# Initial Items
	Item.Inventory.clear()
	Item.add_item("Wallet", &"Key", false)
	Item.add_item("PenCase", &"Key", false)
	Item.add_item("FoldedPaper", &"Key", false)
	Loader.defeated.clear()
	# Reset party
	Party.reset_party()
	Party.reset_all_members()
	Party._init()
	Global.check.emit()

	# Now start the transition
	Loader.white_fadeout(7, 1, 0, 1)
	await Loader.travel_to("TempleWoods", Vector2.ZERO, 0, null, false)
	get_tree().paused = false
	# Skip intro shortcut
	if Input.is_action_pressed("Dash"):
		Global.refresh()
		return

	Global.player.set_anim("OnFloor", false, true)
	Global.player.shadow(false)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	Hud.ui_visible = false
	t.tween_property(Global.camera, "zoom", Vector2(6, 6), 6).from(Vector2(2, 2))
	Loader.save()
	await t.finished
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.set_parallel()
	var getup: Button = Global.room.get_node("GetUp")
	var options: Button = Global.room.get_node("Options")
	getup.show()
	options.show()
	options.position = Vector2(15, 600)
	t.tween_property(getup, "position", Vector2(100, 512), 0.2).from(Vector2(120, 512))
	t.tween_property(getup, "modulate", Color.WHITE, 0.2).from(Color.TRANSPARENT)
	t.tween_property(getup, "size", Vector2(120, 33), 0.2).from(Vector2(41, 33))
	t.tween_property(options, "position", Vector2(15, 583), 0.3).set_delay(1.5)
	while not getup.button_pressed or get_tree().root.has_node("Options"):
		if not is_instance_valid(getup): return
		options.icon = Controller.get_scheme().Start

		if options.button_pressed and not get_tree().root.has_node("Options"):
			await Global.options()
			options.button_pressed = false

		await Event.wait()
		if not is_instance_valid(getup): return

	getup.button_pressed = false
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.set_parallel()
	Hud.disabled = true
	t.tween_property(options, "position", Vector2(15, 600), 0.3)
	t.tween_property(getup, "size", Vector2(41, 33), 0.1)
	t.tween_property(getup, "modulate", Color.TRANSPARENT, 0.1)
	t.tween_property(options, "modulate", Color.TRANSPARENT, 0.1)
	t.tween_property(Global.camera, "zoom", Vector2(5, 5), 5)
	t.tween_property(Global.player.get_node("%Shadow"), "modulate", Color.WHITE, 3).from(Color.TRANSPARENT).set_delay(3)
	await Global.player.set_anim("GetUp", true)
	Global.player.set_anim("IdleUp")
	Global.controllable = true
	Event.pop_tutorial("walk")
	options.hide()
	getup.hide()


func bag_seq() -> void:
	Party.Leader.OV = "Bag"
	Global.player.state = NPC.S.CUSTOM
	Global.player.direction = Vector2.ZERO
	await Global.player.set_anim("BagGet", true)
	Global.player.set_anim("IdleRight")
	Audio.item_sound()
	var bag_ico: Texture = await Loader.load_res("res://art/Icons/Items.tres") as Texture
	bag_ico.region = Rect2(90, 90, 18, 18)
	Item.get_animation(bag_ico, "Flimsy bag", false)
	Event.add_flag(&"HasBag", true)
	Event.give_control()
	Global.player._check_party()


func axe_seq() -> void:
	Item.add_item("LightweightAxe", &"Key")
	Event.pop_tutorial("ov_attack")
	Loader.save()


func first_battle() -> void:
	Global.player.move_dir(Vector2.RIGHT * 2)
	Loader.travel_to("TempleWoods", Vector2(1220, 461), 1, Direction.RIGHT, false)
	await Event.wait(0.2)
	Loader.gray_out(1)
	await Event.wait(0.5)
	Event.take_control()
	Global.player.camera_follow(false)
	Event.camera_move(Vector2(1446, -605), 0)
	Loader.ungray.emit()
	Event.camera_move(Vector2(1486, -300), 5, Tween.EASE_IN_OUT, Tween.TRANS_LINEAR)
	await Event.wait(0.5)
	Global.location_name("Temple Woods")
	await Event.wait(4.5)
	Event.camera_move(Vector2(1558, 318), 0)
	Global.player.hide()
	await Event.camera_move(Vector2(1429, 450), 4, Tween.EASE_OUT)
	Loader.gray_out(1)
	Battle.start("FirstBattle")
	Event.add_flag("EvFirstBattle")
	Event.add_flag("DisableMenus", false)
	Hud.disabled = false


func AlcineFollow1() -> void:
	var Alcine: NPC = Event.npc("EvAlcineBelow")
	Alcine.show()
	Alcine.state = NPC.S.IDLE
	await Event.take_control()
	Global.player.set_anim("IdleUp")
	await Event.wait(0.5)
	Alcine.look_to(Vector2.DOWN)
	await Alcine.bubble("Surprise")
	await Alcine.move_dir(Vector2.UP * 5)
	await Textbox.open("story_0", "was_that_a")
	Event.flag_progress("AlcineFollow", 1)
	Event.give_control(true)


func AlcineFollow2() -> void:
	var Alcine: NPC = Event.npc("Alcine")
	Event.flag_progress("AlcineFollow", 2)
	Event.obj("Pterogon").hide()
	Alcine.position = Vector2(1282, -990)
	Global.player.can_dash = false
	Passive.open("story_0", "hey_wait")
	await Alcine.go_to(Vector2(1334, -1060))
	await Alcine.go_to(Vector2(1681, -1070))
	Alcine.state = NPC.S.CUSTOM
	Alcine.set_anim("Scared")
	Alcine.get_node("Sprite").stop()
	Global.player.can_dash = true
	Loader.save()


func AlcineFollowHelp() -> void:
	var Alcine: NPC = Event.npc("Alcine")
	Alcine.set_anim("IdleRight")
	await Alcine.bubble("Surprise")
	#Hud.disabled = true
	#Hud.hide_all()
	var hp: int = max(Global.bt.get_actor("Pterogon").Health, 5)
	Alcine.z_index = 9
	Loader.white_fadeout(2, 3, 0.5)
	await Alcine.jump_to(Vector2(1660, -1068), 7, 0.5)
	Global.bt.end_battle()
	await Loader.battle_end
	Party.add("Alcine")
	Party.Member1.FirstName = "Spirit"
	Alcine.hide()
	await Event.wait(0.5, false)
	await Battle.start("AlcineFollow2")
	await Event.wait(1)
	Global.bt.get_actor("Pterogon", true).Health = hp
	await Loader.battle_end
	AlcineFollow4()


func AlcineFollow4() -> void:
	var Alcine: NPC = Event.npc("Alcine")
	Global.check.emit()
	Event.take_control()
	while Battle.in_battle: await Event.wait(0.1)
	Event.take_control()
	Party.Member1.FirstName = "Alcine"
	Alcine.z_index = 0
	Party.get_member("Mira").OV = "Bag"
	Alcine.position = Global.room.followers[0].position
	await Global.player.go_to(Vector2(67, -45), true)
	Global.room.followers[0].dont_follow = true
	Global.room.followers[0].hide()
	Alcine.show()
	await Alcine.go_to(Vector2(66, -45), true)
	await Event.wait(0.3)
	Alcine.look_to(Vector2.RIGHT)
	Global.camera.position = Global.player.position - Vector2(18, 0)
	Event.take_control()
	Global.player.look_to(Vector2.LEFT)
	Global.player.position = Vector2(1619, -1068)
	await Textbox.open("story_0", "got_through_that")
	await Global.alcine_naming()
	await Textbox.open("story_0", "use_name")
	await Loader.transition(Direction.RIGHT)
	Event.flag_progress("AlcineFollow", 4)
	Alcine.hide()
	Global.camera.zoom = Vector2(4, 4)
	Hud.disabled = false
	Hud.ui_visible = true
	Event.add_flag("FlameActive")
	Global.room.followers[0].dont_follow = false
	Loader.detransition()
	Hud._on_shrink()
	Event.give_control(true)
	Event.pop_tutorial("party")
	Alcine.default()
	Loader.save()


func enter_amberelm() -> void:
	Global.player.move_dir(Vector2(0, -2))
	await Loader.travel_to("Amberelm", Vector2.ZERO, 1, Direction.UP, false)
	var mira: NPC = Event.npc("MiraCut")
	var alcine: NPC = Event.npc("AlcineCut")
	mira.speed = 50
	alcine.speed = 50
	get_tree().paused = false
	alcine.go_to(Vector2(13, 50), true, false)
	await mira.go_to(Vector2(13, 49), true, false)
	await Event.wait(0.2)
	mira.look_to(Vector2.RIGHT)
	await Event.wait(0.2)
	alcine.look_to(Vector2.RIGHT)
	await Event.wait(0.3)
	alcine.speed = 75
	Event.time_of_day = Event.TOD.MORNING
	Event.day = 0
	await Textbox.open(name, "morning")
	Event.npc("MiraCut").speed = 75
	Event.npc("MiraCut").move_dir(Vector2.UP * 5)
	Event.npc("AlcineCut").chain_moves([Vector2.RIGHT, Vector2.UP * 5])
	await Event.wait(0.8)
	Loader.travel_to("Amberelm", Vector2.ZERO, 0, Direction.UP)
	Event.add_flag("EnterAmberelm")


func enter_amberelm_2() -> void:
	await Event.take_control()
	Global.player.camera_follow(false)
	var t := create_tween()
	Global.player.set_anim("IdleUp")
	t.tween_property(Global.camera, "position", Vector2(150, 252), 7)
	await Event.wait(1)
	Global.location_name("Amberelm")
	await Event.wait(5)
	Loader.gray_out(1, 1)
	await Event.wait(2)
	Event.give_control(true)
	Global.player.position = Vector2(222, 429)
	Event.take_control(false, true)
	await Event.wait(1)
	Global.room.followers[0].position = Global.player.position + Vector2(0, 24)
	Loader.ungray.emit()
	await Textbox.open(name, "what_happened_here")
	await Loader.transition(Direction.RIGHT)
	Global.player.position = Vector2(150, 345)
	Loader.detransition()
	Event.give_control(true)
	Global.player.set_anim("IdleRight")


func amberelm_guardian() -> void:
	Battle.start("StoneGuardianBoss")
	await Loader.battle_end
	if Loader.battle_result == 1:
		Party.set_to(["Mira"])
		Loader.ungray.emit()
		Event.to_day = 0
		Event.to_time = 5
		Event.add_flag("BeatStoneGuardian")
		Event.time_transition()


func oct31_night() -> void:
	Item.remove_item("LightweightAxe", &"Key")
	Party.get_member("Mira").Weapon = load("res://database/Items/KeyItems/NoWeapon.tres")
	Event.add_flag("BeatStoneGuardian")
	await Loader.travel_to("WitheredLeaves", Vector2(750, -211), 0, "none", false)
	await Event.no_player()
	await Event.spawn("Mira", Vector2(770, -211), Direction.LEFT)
	await Event.spawn("Daze", Vector2(670, -211), Direction.RIGHT)
	await Textbox.open(name, "daze_introduction")
	Item.remove_item("LightweightAxe", &"Key")
	Event.add_flag("DisableVeinet")
	Event.remove_flag("HideDate")
	Party.set_to(["Mira"])
	Party.Leader.ClutchDmg = false
	await Loader.travel_to("WitheredLeaves", Vector2(775, -211))
	Loader.save()
