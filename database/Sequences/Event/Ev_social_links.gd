extends Node


func sl_maple_1() -> void:
	await Loader.travel_to("Pyrson", Vector2(362, 778), 0, "wait")
	Event.no_player()
	await Event.spawn("Mira:MiraOVBag", Vector2(300, 778), Direction.RIGHT)
	await Event.spawn("Maple", Vector2(350, 778), Direction.LEFT)
	Event.zoom(5)
	Transition.unwipe()
	await Event.wait(1)
	await Textbox.open("sl_maple", "rank1_1")
	Event.progress_by_time(1)
	Event.time_transition()


func sl_asteria_1() -> void:
	await Loader.travel_to("Pyrson", Vector2(490, 680), 0, "wait")
	Event.no_player()
	var mira: NPC = await Event.spawn("Mira:MiraOV", Vector2(506, 680), Direction.RIGHT)
	var asteria: NPC = Event.npc("AsteriaPlaza")
	asteria.position = Vector2(506, 640)
	asteria.look_to(Direction.RIGHT)
	await Transition.unwipe()
	mira.state = NPC.S.CUSTOM
	mira.set_anim("SitRight")
	asteria.set_anim("IdleRight")
	Event.zoom(5, true)
	await Event.wait(2)
	await Textbox.open("sl_asteria", "rank1_1")
	Event.add_flag("sl_asteria_1")
	Event.progress_by_time(1)
	Event.time_transition()
