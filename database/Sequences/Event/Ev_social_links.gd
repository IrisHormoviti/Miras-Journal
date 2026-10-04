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
