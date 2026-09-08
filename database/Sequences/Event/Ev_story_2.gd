extends Node


func nov3_morning() -> void:
	Item.add_item("LightweightAxe", &"Key", false, false)
	Party.get_member("Mira").Weapon = load("res://database/Items/KeyItems/LightweightAxe.tres")
	Event.add_flag("LampInMirasRoom", false)
	await Loader.travel_to("Pyrson;HomeBuilding-MyRoom", Vector2(98, 424), 0, "", false)
	Event.no_player()
	Event.npc("RoomMira").state = NPC.S.CUSTOM
	Event.npc("RoomMira").show()
	Event.npc("RoomMira").position = Vector2(84, 424)
	Event.npc("RoomMira").set_anim("Sleep")
	await Event.wait(2)
	await Textbox.open(name, "nov3_morning", false)
	Party.set_to(["Mira", "Alcine"])
	Event.to_day = 3
	Event.to_time = 2
	Event.time_transition()
	#await Loader.travel_to("Pyrson;HomeBuilding-MyRoom", Vector2(102, 440))


func nov3_afternoon() -> void:
	await Loader.travel_to("Pyrson;HomeBuilding-MyRoom", Vector2(98, 424), 0, "", false)
	Event.no_player()
	Event.npc("RoomMira").state = NPC.S.CUSTOM
	Event.npc("RoomMira").show()
	Event.npc("RoomMira").position = Vector2(90, 412)
	Event.npc("RoomMira").set_anim("SitRight")
	await Event.wait(2)
	await Textbox.open(name, "nov3_afternoon", false)
	await Loader.travel_to("Pyrson;HomeBuilding-MyRoom", Vector2(102, 440))
	Global.player.look_to(Direction.RIGHT)


func nov3_enterSG() -> void:
	await Loader.travel_to("ShardGardens", Vector2(26, 84), 0, "", false)
	Global.heal_party()
	Party.reset_party()
	Party.add("Alcine")
	Party.add("Asteria")
	Party.add("Daze")
	Global.player.camera_follow(false)
	Global.location_name("Shard Gardens")
	Global.camera.position = Vector2(663, 241)
	var t := create_tween().set_ease(Tween.EASE_IN_OUT)
	t.tween_property(Global.camera, "position", Vector2(190, 84), 6)
	await Event.wait(4)
	Global.player.collision(false)
	await Event.take_control(false, true)
	await Global.player.move_dir(Vector2(6, 0))
	await Textbox.open(name, "nov3_sg_enter")
	Event.give_control(true)
	Event.add_flag("Nov3_WentToSG")
	await Event.wait(2)
	Passive.open(name, "very_shiny")


func sg_bunker_entrance() -> void:
	if Event.f("DefeatedLazuliteHeart"):
		await Event.take_control()
		await Textbox.open(name, "enter_bunker_2")
		Event.give_control()
	elif Party.has_member_index(3):
		await Event.take_control()
		Textbox.open(name, "lazulite_warning")
	else:
		await Textbox.open(name, "sg_find_bunker")
		Event.give_control()


func lazulite_boss() -> void:
	await Global.player.bubble("Surprise")
	await Battle.start("LazuliteHeartBoss")
	await Loader.battle_end
	print("battle done")
	Loader.ungray.emit()
	await Textbox.open(name, "lazulite_heart_after")
	Loader.white_fadeout(0.5, 0.3, 0.5)
	Event.add_flag("DefeatedLazuliteHeart")
	Event.progress_by_time(1)
	Event.time_transition()
