extends Node


func new_game() -> void:
	Global.FirstStartTime = Time.get_unix_time_from_system()

	# Hide any UI
	if get_tree().root.has_node("/root/Textbox"): $"/root/Textbox"._on_close()
	if get_tree().root.has_node("/root/Initializer"): $"/root/Initializer".queue_free()
	PartyUI.hide_all()
	# Initial flags
	Event.Flags.clear()
	Event.add_flag("Started")
	Event.add_flag("HasBag", false)
	Event.add_flag("DisableMenus", true)
	Event.add_flag("HideDate", true)
	Event.add_flag("DisableVeinet")
	Event.add_flag("time", Event.TOD.NIGHT)
	Event.add_flag("day", 0)
	Event.Day = 0
	Event.TimeOfDay = Event.TOD.NIGHT
	# Initial Items
	Item.KeyInv.clear()
	Item.ConInv.clear()
	Item.MatInv.clear()
	Item.BtiInv.clear()
	Item.add_item("Wallet", &"Key", false)
	Item.add_item("PenCase", &"Key", false)
	Item.add_item("FoldedPaper", &"Key", false)
	Loader.Defeated.clear()
	# Reset Party
	Global.Party.reset_party()
	Global.reset_all_members()
	Global.init_party(Global.Party)
	Global.check_party.emit()

	# Now start the transition
	Loader.white_fadeout(7, 1, 0, 1)
	Loader.travel_to("TempleWoods", Vector2.ZERO, 0, -1, "none", false)
	get_tree().paused = false
	await Global.area_initialized
	# Skip intro shortcut
	if Input.is_action_pressed("Dash"):
		Global.refresh()
		return
	Global.Player.BodyState = NPC.CUSTOM
	Global.Player.set_anim("OnFloor", false, true)
	Global.Player.shadow(false)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	PartyUI.UIvisible = false
	t.tween_property(Global.Camera, "zoom", Vector2(6, 6), 6).from(Vector2(2, 2))
	Loader.save()
	await t.finished
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.set_parallel()
	var getup: Button = Global.Area.get_node("GetUp")
	var options: Button = Global.Area.get_node("Options")
	getup.show()
	options.show()
	options.position = Vector2(15, 600)
	t.tween_property(getup, "position", Vector2(100, 512), 0.2).from(Vector2(120, 512))
	t.tween_property(getup, "modulate", Color.WHITE, 0.2).from(Color.TRANSPARENT)
	t.tween_property(getup, "size", Vector2(120, 33), 0.2).from(Vector2(41, 33))
	t.tween_property(options, "position", Vector2(15, 583), 0.3).set_delay(1.5)
	while not getup.button_pressed or get_tree().root.has_node("Options"):
		if not is_instance_valid(getup): return
		options.icon = Global.get_controller().Start
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
	PartyUI.disabled = true
	t.tween_property(options, "position", Vector2(15, 600), 0.3)
	t.tween_property(getup, "size", Vector2(41, 33), 0.1)
	t.tween_property(getup, "modulate", Color.TRANSPARENT, 0.1)
	t.tween_property(options, "modulate", Color.TRANSPARENT, 0.1)
	t.tween_property(Global.Camera, "zoom", Vector2(5, 5), 5)
	t.tween_property(Global.Player.get_node("%Shadow"), "modulate", Color.WHITE, 3).from(Color.TRANSPARENT).set_delay(3)
	await Global.Player.set_anim("GetUp", true)
	Global.Player.set_anim("IdleUp")
	Global.Controllable = true
	Event.pop_tutorial("walk")


func bag_seq() -> void:
	Global.Party.Leader.OV = "Bag"
	Global.Player.BodyState = NPC.CUSTOM
	Global.Player.direction = Vector2.ZERO
	await Global.Player.set_anim("BagGet", true)
	Global.Player.set_anim("IdleRight")
	Global.item_sound()
	var bag_ico: Texture = preload("res://art/Icons/Items.tres")
	bag_ico.region = Rect2(90, 90, 18, 18)
	Item.get_animation(bag_ico, "Flimsy bag", false)
	Event.add_flag(&"HasBag", true)
	Event.give_control()
	Global.Player._check_party()


func axe_seq() -> void:
	Item.add_item("LightweightAxe", &"Key")
	Event.pop_tutorial("ov_attack")
	Loader.save()


func first_battle() -> void:
	Global.Player.move_dir(Vector2.RIGHT * 2)
	Loader.travel_to("TempleWoods", Vector2(1220, 461), 1, -1, "R", false)
	await Event.wait(0.2)
	Loader.gray_out(1)
	await Event.wait(0.5)
	Event.take_control()
	Global.Player.camera_follow(false)
	Event.camera_move(Vector2(1446, -605), 0)
	Loader.ungray.emit()
	Event.camera_move(Vector2(1486, -300), 5, Tween.EASE_IN_OUT, Tween.TRANS_LINEAR)
	await Event.wait(0.5)
	Global.location_name("Temple Woods")
	await Event.wait(4.5)
	Event.camera_move(Vector2(1558, 318), 0)
	Global.Player.hide()
	await Event.camera_move(Vector2(1429, 450), 4, Tween.EASE_OUT)
	Loader.gray_out(1)
	Loader.start_battle("FirstBattle")
	Event.add_flag("EvFirstBattle")
	Event.add_flag("DisableMenus", false)
	PartyUI.disabled = false


func AlcineFollow1() -> void:
	var Alcine: NPC = Event.npc("EvAlcineBelow")
	Alcine.show()
	Alcine.BodyState = NPC.IDLE
	await Event.take_control()
	Global.Player.set_anim("IdleUp")
	await Event.wait(0.5)
	Alcine.look_to(Vector2.DOWN)
	await Alcine.bubble("Surprise")
	await Alcine.move_dir(Vector2.UP * 5)
	await Global.textbox("story_0", "was_that_a")
	Event.flag_progress("AlcineFollow", 1)
	Event.give_control(true)


func AlcineFollow2() -> void:
	var Alcine: NPC = Event.npc("Alcine")
	Event.flag_progress("AlcineFollow", 2)
	Event.obj("Pterogon").hide()
	Alcine.position = Vector2(1282, -990)
	Global.Player.can_dash = false
	Global.passive("story_0", "hey_wait")
	await Alcine.go_to(Vector2(1334, -1060))
	await Alcine.go_to(Vector2(1681, -1070))
	Alcine.BodyState = NPC.CUSTOM
	Alcine.set_anim("Scared")
	Alcine.get_node("Sprite").stop()
	Global.Player.can_dash = true
	Loader.save()


func AlcineFollow3() -> void:
	var Alcine: NPC = Event.npc("Alcine")
	await Event.take_control()
	Global.Party.Leader.ClutchDmg = true
	Global.Player.set_anim("IdleRight")
	Global.Player.camera_follow(false)
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	t.tween_property(Global.get_cam(), "position:x", 1650, 1)
	Alcine.set_anim("Scared")
	await t.finished
	Event.wait(0.5)
	await Global.textbox("story_0", "approach")
	Global.Player.collision(false)
	await Global.Player.go_to(Vector2(67, -45), true)
	await Event.wait(0.3)
	Global.Player.BodyState = NPC.CUSTOM
	Global.Player.set_anim("ReachOut")
	Global.Player.position = round(Global.Player.position)
	t = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	t.tween_property(Alcine.get_node("Glow"), "energy", 0.6, 2)
	t.tween_property(Alcine.get_node("Glow"), "texture_scale", 3, 2)
	Global.Player.get_node("Flame").flicker = false
	t.tween_property(Global.Player.get_node("Flame"), "energy", 0, 2)
	await t.finished
	Event.f_past("FlameActive", false)
	await Global.textbox("story_0", "you_ok")
	Alcine.set_anim("ScaredTurn2", false, true)
	await Event.wait(0.5)
	await Alcine.go_to(Global.Player.position + Vector2(12, 0))
	t = create_tween()
	t.tween_property(Alcine, "position", Global.Player.position + Vector2(2, 4), 0.1)
	Alcine.BodyState = Alcine.CUSTOM
	Alcine.set_anim("Hug")
	Global.Player.bubble("Surprise")
	await Event.wait(1.5)
	await Global.textbox("story_0", "haha")
	#await Global.textbox("story_0", "good_on_you")
	Alcine.look_to(Vector2.RIGHT)
	await Alcine.bubble("Surprise")
	await Alcine.go_to(Vector2(1630, -1081), false)
	Event.obj("Pterogon").show()
	Event.obj("Pterogon").play("Fly")
	t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	t.tween_property(Event.obj("Pterogon"), "position", Vector2(1731, -1080), 2).from(Vector2(1805, -1183))
	Global.Player.bubble("Surprise")
	Global.Player.reset_sprite()
	await Event.wait()
	Global.Player.set_anim("EntrancePrep")
	Global.get_cam().position += Vector2(50, 0)
	await Alcine.go_to(Vector2(1607, -1081), false)
	await Alcine.go_to(Vector2(1607, -1100), false)
	Alcine.BodyState = NPC.CUSTOM
	Alcine.set_anim("Scared")
	await Event.wait(1)
	Event.obj("Pterogon").play("Idle")
	await Global.textbox("story_0", "stay_back")
	Loader.Attacker = Event.obj("Pterogon")
	await Event.wait(0.1)
	Global.Party.Leader.Health = max(Global.Party.Leader.Health, 30)
	Global.Party.Leader.ClutchDmg = true
	Event.flag_progress("AlcineFollow", 3)
	Loader.start_battle("AlcineFollow1")


func AlcineFollowHelp() -> void:
	var Alcine: NPC = Event.npc("Alcine")
	Alcine.set_anim("IdleRight")
	await Alcine.bubble("Surprise")
	#PartyUI.disabled = true
	#PartyUI.hide_all()
	var hp: int = max(Global.Bt.get_actor("Pterogon").Health, 5)
	Alcine.z_index = 9
	Loader.white_fadeout(2, 3, 0.5)
	await Alcine.jump_to(Vector2(1660, -1068), 7, 0.5)
	Global.Bt.end_battle()
	await Loader.battle_end
	Global.Party.add("Alcine")
	Global.Party.Member1.FirstName = "Spirit"
	Alcine.hide()
	await Event.wait(0.5, false)
	await Loader.start_battle("AlcineFollow2")
	await Event.wait(1)
	Global.Bt.get_actor("Pterogon", true).Health = hp
	await Loader.battle_end
	AlcineFollow4()


func AlcineFollow4() -> void:
	var Alcine: NPC = Event.npc("Alcine")
	Global.check_party.emit()
	Event.take_control()
	while Loader.InBattle: await Event.wait(0.1)
	Event.take_control()
	Global.Party.Member1.FirstName = "Alcine"
	Alcine.z_index = 0
	Event.allow_skipping = false
	Query.find_member("Mira").OV = "Bag"
	Alcine.position = Global.Area.Followers[0].position
	await Global.Player.go_to(Vector2(67, -45), true)
	Global.Area.Followers[0].dont_follow = true
	Global.Area.Followers[0].hide()
	Alcine.show()
	await Alcine.go_to(Vector2(66, -45), true)
	await Event.wait(0.3)
	Alcine.look_to(Vector2.RIGHT)
	Global.Camera.position = Global.Player.position - Vector2(18, 0)
	Event.take_control()
	Global.Player.look_to(Vector2.LEFT)
	Global.Player.position = Vector2(1619, -1068)
	await Global.textbox("story_0", "got_through_that")
	await Global.alcine_naming()
	await Global.textbox("story_0", "use_name")
	await Loader.transition("R")
	Event.flag_progress("AlcineFollow", 4)
	Alcine.hide()
	Global.get_cam().zoom = Vector2(4, 4)
	PartyUI.disabled = false
	PartyUI.UIvisible = true
	Event.allow_skipping = true
	Event.add_flag("FlameActive")
	Global.Area.Followers[0].dont_follow = false
	Loader.detransition()
	PartyUI._on_shrink()
	Event.give_control(true)
	Event.pop_tutorial("party")
	Alcine.default()
	Loader.save()


func enter_amberelm() -> void:
	Global.Player.move_dir(Vector2(0, -2))
	await Loader.travel_to("Amberelm", Vector2.ZERO, 1, -2, "U", false)
	var mira: NPC = Global.Area.get_node("EvEntranceCutscene/MiraCut")
	var alcine: NPC = Global.Area.get_node("EvEntranceCutscene/AlcineCut")
	mira.speed = 50
	alcine.speed = 50
	get_tree().paused = false
	alcine.go_to(Vector2(12, 50), true, false)
	await mira.go_to(Vector2(12, 49), true, false)
	await Event.wait(0.2)
	mira.look_to(Vector2.RIGHT)
	await Event.wait(0.2)
	alcine.look_to(Vector2.RIGHT)
	await Event.wait(0.3)
	alcine.speed = 75
	Event.TimeOfDay = Event.TOD.MORNING
	Event.Day = 1
	await Global.textbox(name, "morning")
	mira.speed = 75
	mira.move_dir(Vector2.UP * 5)
	alcine.chain_moves([Vector2.RIGHT, Vector2.UP * 5])
	await Event.wait(0.8)
	Loader.travel_to("Amberelm", Vector2.ZERO, 0, -1, "U")
	Event.add_flag("EnterAmberelm")


func enter_amberelm_2() -> void:
	await Event.take_control()
	Global.Player.camera_follow(false)
	var t := create_tween()
	Global.Player.set_anim("IdleUp")
	t.tween_property(Global.get_cam(), "position", Vector2(150, 252), 7)
	await Event.wait(1)
	Global.location_name("Amberelm")
	await Event.wait(5)
	Loader.gray_out(1, 1)
	await Event.wait(2)
	Event.give_control(true)
	Global.Player.position = Vector2(222, 429)
	Event.take_control(false, true)
	await Event.wait(1)
	Global.Area.Followers[0].position = Global.Player.position + Vector2(0, 24)
	Loader.ungray.emit()
	await Global.textbox(name, "what_happened_here")
	await Loader.transition("R")
	Global.Player.position = Vector2(150, 345)
	Loader.detransition()
	Event.give_control(true)
	Global.Player.set_anim("IdleRight")


func rest_amberelm() -> void:
	Event.progress_by_time(1)
	if await PartyUI.confirm_time_passage("Rest", "Fully recover Health."):
		await Loader.save()
		Event.no_player()
		Global.check_party.emit()
		get_tree().paused = false
		Global.Area.Followers[0].hide()
		var mira: NPC = await Event.spawn("Mira:MiraOVBag", Vector2(80, 354), "D", true, 8)
		var alcine: NPC = await Event.spawn("Alcine", Vector2(100, 340), "D", true, 8)
		mira.BodyState = NPC.NONE
		alcine.BodyState = NPC.NONE
		mira.set_anim("SitDown")
		alcine.set_anim("IdleDown")
		Loader.detransition()
		Global.get_cam().zoom = Vector2(6, 6)
		Global.get_cam().position = Vector2(85, 360)
		await Event.wait(1)
		await Global.textbox(name, "rest_amberelm", true)
		await Loader.transition("")
		await Event.wait(1)
		Global.heal_party()
		Event.ToDay = 0
		Event.ToTime = Event.TOD.DAYTIME
		await Event.time_transition()
		Global.heal_party()
	else: Event.give_control()


func oct0_daytime() -> void:
	Event.no_player()
	await Loader.detransition()
	await Loader.transition("R")
	Global.get_cam().zoom = Vector2(4, 4)
	var mira: NPC = Event.npc("Mira")
	var alcine: NPC = Event.npc("Alcine")
	mira.set_anim("SitDown")
	alcine.set_anim("IdleDown")
	await Global.textbox(name, "wake_amberelm", true)
	Event.add_flag("EvRestAmberelm", true)
	await Loader.travel_to("Amberelm", Vector2(120, 360), 0, 7)
	Loader.save()


func amberelm_guardian() -> void:
	Loader.start_battle("StoneGuardianBoss")
	await Loader.battle_end
	if Loader.BattleResult == 1:
		Global.Party.set_to_strarr(["Mira"])
		Loader.ungray.emit()
		Event.ToDay = 0
		Event.ToTime = 5
		Event.add_flag("BeatStoneGuardian")
		Event.time_transition()


func oct0_afternoon() -> void:
	await Global.textbox(name, "oct0_afternoon", true)
	Global.Complimentaries.append("FluidBlast")
	await Loader.travel_to("Amberelm", Vector2(2218, -132), 2)
	Loader.save()


func oct0_night() -> void:
	Event.add_flag("BeatStoneGuardian")
	await Loader.travel_to("WitheredLeaves", Vector2(750, -211), 0, -1, "none", false)
	await Event.no_player()
	#Loader.detransition()
	await Event.spawn("Mira", Vector2(770, -211), "L")
	await Event.spawn("Daze", Vector2(670, -211), "R")
	await Global.textbox(name, "daze_introduction")
	Item.remove_item("LightweightAxe", &"Key")
	Event.add_flag("DisableVeinet")
	Event.remove_flag("HideDate")
	Global.Party.set_to(["Mira"])
	Global.Party.Leader.ClutchDmg = false
	await Loader.travel_to("WitheredLeaves", Vector2(775, -211))
