extends Node


func nov1_morning() -> void:
	Loader.gray_out(1)
	await Textbox.open(name, "nov1_dream")
	await Loader.travel_to("WitheredLeaves", Vector2.ZERO, 1)
	await Event.spawn("Daze", "TentInside+(-8,-5)", "Sleep", 1, true)
	await Event.spawn("Mira", "TentInside+(8,0)", "Sleep", 1, true)
	Loader.ungray.emit()
	Event.no_player()
	Textbox.open(name, "nov1_morning")


func nov1_daytime() -> void:
	await Loader.travel_to("WitheredLeaves", Vector2(-96, -384), 1)
	Event.no_player()
	await Event.spawn("Mira", "TentInside+(8,0)", "Sleep", 1, true)
	await Textbox.open(name, "nov1_daytime_0")
	await Loader.travel_to("WitheredLeaves", Vector2(720, -211), 0, Direction.DOWN, false)
	Event.no_player()
	Event.zoom(5)
	await Event.spawn("Mira", Vector2(770, -211), "SitLeft")
	await Event.spawn("Daze", Vector2(670, -211), Direction.RIGHT)
	await Textbox.open(name, "nov1_daytime")
	Party.set_to(["Mira", 'Daze'])
	Item.remove_item("LightweightAxe", &"Key")
	Party.get_member("Mira").Weapon = load("res://database/Items/KeyItems/NoWeapon.tres")
	await Loader.travel_to("WitheredLeaves", Vector2(775, -211))


func daze_enemy_1() -> void:
	if Event.day == 1 and Party.has_member("Mira") and Party.has_member("Daze"):
		Event.npc("P").look_to(Direction.LEFT)
		Passive.open(name, "daze_enemy_1")
		Event.npc("P").bubble("Surprise")
		await Event.camera_move(Event.npc("EnemyFlowent1").position + Vector2(48, 0))
		Event.npc("EnemyFlowent1").look_to(Direction.LEFT)
		await Event.wait(2)
		Event.npc("F1").speed = 150
		await Event.npc("F1").go_to(Event.npc("EnemyFlowent1").position, false, false, Vector2.LEFT, 10)
		Global.intro_effect(Event.npc("EnemyFlowent1"))
		Loader.attacker = Event.npc("EnemyFlowent1")
		Battle.start("DazeEnemyTutorial", 1)
		await Loader.battle_end
		Textbox.open("story_1", "dont_treat_me_like_a_child")
	else: Event.give_control()


func daze_enemy_2() -> void:
	if Event.day == 1 and Party.has_member("Mira") and Party.has_member("Daze"):
		await Event.npc("P").bubble("Surprise")
		Battle.start("SkritcherRootDaze", 2)
	else: Event.give_control()


func where_is_alcine_1() -> void:
	await Loader.transition(Direction.LEFT)
	Event.remove_flag("HasBag")
	Event.add_flag("AlcineAlone")
	Party.reset_party()
	Party.Leader = Party.get_member("Alcine")
	Party.Leader.Controllable = true
	await Loader.travel_to("WitheredLeaves", Vector2(-976, 167), 0, "")
	Event.give_control()
	Loader.save()


func WL_alcine_slide() -> void:
	await Event.take_control()
	Global.player.collision(false)
	Global.player.set_anim("IdleDown")
	Global.player.state = NPC.S.NONE
	await Event.jump_to_global(Global.player, Vector2(-104, 250), 8, 0)
	Global.player.set_anim("IdleUp")
	await Event.wait(1)
	await Event.jump_to_global(Global.player, Vector2(-110, 198), 5, 0.5)
	Event.give_control()


func amberelm_reunion() -> void:
	Global.player.camera_follow(false)
	await Event.take_control()
	await Event.wait(0.3)
	Global.player.look_to(Direction.LEFT)
	await Global.player.bubble("Surprise")
	await Event.spawn("Mira", Vector2(2224, -157), "SitDown", 7, true)
	await Event.spawn("Daze", Vector2(2200, -157), "SitDown", 7, true)
	Global.camera.position = Vector2(2247, -157)
	await Event.wait(0.3)
	Global.player.chain_moves([Vector2.LEFT * 2, Vector2.DOWN, Vector2.LEFT * 2])
	await Event.wait(1)
	await Event.npc("Mira").move_dir(Vector2.DOWN)
	Event.npc("Mira").look_to(Direction.RIGHT)
	await Event.npc("Mira").bubble("Surprise")
	await Textbox.open(name, "amberelm_reunion")
	await Loader.transition(Direction.RIGHT)
	Event.add_flag("HasBag")
	Event.remove_flag("AlcineAlone")
	Party.set_to(["Mira"])
	Event.to_day = 1
	Event.to_time = 5
	await Event.time_transition()


func nov2_morning() -> void:
	Loader.gray_out(1)
	await Loader.travel_to("WitheredLeaves", Vector2(-96, -384), 1)
	Loader.ungray.emit()
	Event.no_player()
	await Textbox.open(name, "nov2_morning")
	Event.remove_flag("InCamp")
	Event.add_flag("WLLeftSideOpen")
	Event.to_day = 2
	Event.to_time = 2
	await Event.time_transition()
	#await Loader.travel_to("WitheredLeaves", Vector2(775, -211), 0, -1, Direction.DOWN, false)
	#Party.set_to(["Alcine"])
	#Event.remove_flag("HasBag")
	#Event.add_flag("AlcineAlone")
	#Event.remove_flag("HideDate")
	#await Loader.travel_to("WitheredLeaves", Vector2(775, -211))


func nov2_daytime() -> void:
	await Loader.travel_to("WitheredLeaves", Vector2(-96, -384), 1, "none", false)
	Event.no_player()
	await Event.spawn("Mira", "TentInside+(8,0)", "Sleep")
	Loader.ungray.emit()
	await Textbox.open(name, "nov2_daytime")
	Party.set_to(["Mira", "Alcine", "Daze"])
	Event.add_flag("HasBag")
	Event.remove_flag("AlcineAlone")
	Event.remove_flag("HideDate")
	await Loader.travel_to("WitheredLeaves", Vector2(775, -211), 0, Direction.DOWN)
	Event.npc("F1").position.x += 24
	Event.npc("F2").position.y -= 24
	await Event.take_control(false, true)
	await Textbox.open(name, "nov2_daytime_party")
	var path: Array[Vector2] = [Vector2(779, -147), Vector2(289, -144), Vector2(301, -227), Vector2(398, -218), Vector2(527, -754), Vector2(486, -840), Vector2(351, -836)]
	Event.give_control()
	Event.npc("F2").speed = 80
	await Event.npc("F2").chain_positions(path)
	await Passive.open(name, "right_here")
	await Event.wait(3)
	Event.npc("F2").dont_follow = false
	Event.npc("F2").state = NPC.S.CONTROLLED


func WL_bunker_switch() -> void:
	await Loader.transition()
	await Loader.travel_to("WitheredLeaves", Vector2(-250, -1010), 0, "none", false)
	await Event.no_player()
	await Event.spawn("Mira:MiraOVBag", Vector2(-250, -1000), Direction.UP)
	await Event.spawn("Daze", Vector2(-275, -1010), Direction.UP)
	await Event.spawn("Alcine", Vector2(-275, -990), Direction.UP)
	await Loader.detransition(Direction.UP)
	await Textbox.open(name, "WL_bunker_switch")
	await Loader.travel_to("WitheredLeaves", Vector2(-275, -986), 0, Direction.UP)
	await Loader.save()


func asteria_boss() -> void:
	await Event.take_control()
	await Textbox.open(name, "asteria_boss", true)
	await Event.spawn("Asteria", Vector2(-286, 308), Direction.LEFT)
	await Event.wait(1)
	await Battle.start("AsteriaBoss")
	Event.npc("Asteria").hide()
	await Loader.battle_end
	if Loader.battle_result == 1:
		Event.npc("Asteria").show()
		Event.add_flag("AsteriaBoss", 5)
		Event.take_control()
		Event.npc("F1").move_dir(Vector2(1, 0))
		await Textbox.open(name, "asteria_boss_after")
		asteria_joins()


func asteria_joins() -> void:
	Event.add_flag("InCamp")
	Party.set_to(["Mira"])
	if Event.time_of_day != Event.TOD.EVENING:
		Event.to_day = 2
		Event.to_time = Event.TOD.EVENING
		await Event.time_transition()

	await Loader.travel_to("WitheredLeaves", Vector2(774, -202), 0, Direction.RIGHT, false)
	Event.npc("AlcineCamp").position = Vector2(746, -232)
	Event.npc("P").look_to(Direction.LEFT)
	await Textbox.open(name, "asteria_joins")
	Event.give_control(true)
	Event.add_flag("VeinetDisabled")
	Loader.save()


func enter_pyrson() -> void:
	await Loader.travel_to("Pyrson", Vector2(0, 0), 0, Direction.RIGHT, false)
	Event.remove_flag("InCamp")
	Global.player.hide()
	Global.player.camera_follow(false)
	Loader.ungray.emit()
	Event.camera_move(Vector2(568, 669))
	Event.camera_move(Vector2(214, 172), 5)
	Global.location_name("Pyrson")
	await Event.wait(5)
	Event.spawn("Asteria", Vector2i(214, 182), Direction.RIGHT)
	await Textbox.open(name, "enter_pyrson")
	Party.set_to(["Mira", "Alcine", "Daze"])
	Global.check.emit()
	Global.player.show()
	Event.teleport_followers()
	Event.give_control(true)
	Event.npc("Asteria").speed = 120
	await Event.npc("Asteria").go_to(Vector2(372, 227), false)
	await Event.npc("Asteria").move_dir(Vector2.UP)
	Event.npc("Asteria").queue_free()
