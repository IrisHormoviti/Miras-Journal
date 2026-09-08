extends Node


func sl_linde() -> int:
	if Event.date_is_reserved(): return 0
	if not Event.f("sl_linde_1"):
		return 1
	return 0


func sl_maple() -> int:
	if Event.date_is_reserved(): return 0
	return 0


func sl_asteria_outside_house() -> int:
	if Event.date_is_reserved(): return 0
	if Event.f("sl_asteria_1") and not Event.f("sl_asteria_2") and (Event.time_of_day == Event.TOD.AFTERNOON or Event.time_of_day == Event.TOD.EVENING):
		return 2
	return 0


func sl_asteria() -> int:
	if Event.date_is_reserved(): return 0
	if Event.time_of_day > 3 and Event.day >= 3 and not Event.f("sl_asteria_1") and Event.f("EvSwitchCastLines2"):
		return 1
	return 0
