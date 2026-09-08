extends Room


func default() -> void:
	if not Event.add_flag("ArenaRound", 1):
		Global.reset_all_members()
	Party.reset_party()
	await Event.wait(0.1)
	for i in range(1, 3):
		await start_round(i)
	Party.add("Alcine")
	$Bg.texture = load("res://art/Backgrounds/ArenaBg/TempleRoadBg.png")
	for i in range(3, 7):
		await start_round(i)


func start_round(i: int) -> void:
	if Event.add_flag("ArenaRound", i): return
	for j in Party.current:
		if j:
			j.add_health(int(j.MaxHP / 3))
			j.add_aura(int(j.MaxAura / 3))
	$Round.text = "ROUND " + str(i)
	await Event.wait(0.1)
	await Battle.start("ArenaBattles/Round" + str(i))
	Loader.save("Arena")
	await Loader.battle_end
	Event.flag_progress("ArenaRound", i)
