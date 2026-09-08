extends Node


func sleep_home() -> void:
	await Event.take_control()
	Event.set_time(Event.TOD.MORNING)
	Event.remove_flag("eepy")
	#await Event.next_day
	#Loader.travel_to("Pyrson;HomeBuilding-MyRoom", Vector2(178, 482), 0, 2, "")


func WL_void() -> void:
	await Event.take_control(false, true, true)
	await Textbox.open("interact_abad", "WL_void")
	Event.give_control()


func hurt_1() -> void:
	Party.Leader.Health -= 1
	Audio.ui_sound("Crunch")
	Hud.hit_partybox(0, 4, 3)
	if Party.Leader.Health < 10:
		if not Event.f("ShardsLowHP") and Party.has_member("Asteria"):
			Event.take_control(false, true, true)
			Event.add_flag("ShardsLowHP")
			await Textbox.open("interact_abad", "shards_low_hp")
			Event.give_control()
		Party.Leader.Health += 1
	Global.check.emit()


func wake_home() -> void:
	Party.reset_party()
	await Loader.travel_to("Pyrson;HomeBuilding-MyRoom", Vector2(106, 414))
	Global.player.look_to(Direction.RIGHT)
	Event.give_control()


func return_home_pyrson() -> void:
	Party.reset_party()
	Global.heal_party()
	await Loader.travel_to("Pyrson", Vector2(97, 157))
	await Textbox.open("interact_pyrson", "return_home_pyrson")
	Event.give_control()
