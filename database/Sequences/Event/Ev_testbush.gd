extends Node


func jump_playtest() -> void:
	await Textbox.open("testbush", "jump_playtest")
	Event.day = 3
	Event.to_time = Event.TOD.AFTERNOON
	Event.remove_flag("HideDate")
	Event.time_transition()


func waste_time() -> void:
	await Event.take_control()
	await Loader.transition()
	Event.progress_by_time(1)
	await Event.time_transition()
	Loader.detransition()
	Event.give_control()


func demo_credits() -> void:
	await Event.take_control()
	var scene: PackedScene = await Loader.load_res("res://UI/Misc/CreditsRoll.tscn")
	get_tree().root.add_child(scene.instantiate())
