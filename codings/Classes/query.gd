extends Node
class_name Query


static func str_length(string: String) -> int:
	return string.length()


static func get_mmm(month: int) -> String:
	match month:
		1: return "Jan"
		2: return "Feb"
		3: return "Mar"
		4: return "Apr"
		5: return "May"
		6: return "Jun"
		7: return "Jul"
		8: return "Aug"
		9: return "Sep"
		10: return "Oct"
		11: return "Nov"
		12: return "Dec"

	return "???"


static func get_month_name(month: int) -> String:
	match month:
		1: return "January"
		2: return "February"
		3: return "March"
		4: return "April"
		5: return "May"
		6: return "June"
		7: return "July"
		8: return "August"
		9: return "September"
		10: return "October"
		11: return "November"
		12: return "December"

	return "Unknown"


static func get_month(day: int) -> int:
	if day > 0 and day <= 30: return 11
	if day <= 0: return 10
	else: return 0


static func get_date_day(day: int) -> String:
	return str(wrapi(day, 1, 32))


static func tilemapize(pos: Vector2) -> Vector2:
	return Global.room.local_to_map(pos)


static func globalize(coords: Vector2i) -> Vector2:
	return Global.room.map_to_local(coords)


static func get_state(stat: StringName) -> State:
	return await Loader.load_res("res://database/States/" + stat + ".tres")


static func in_360(nm: int) -> int:
	return wrapi(nm, 0, 359)


static func member_exists(Name: StringName) -> bool:
	for i in Party.members:
		if i.codename == Name: return true

	return false


static func calc_num(ab: Ability = Global.bt.CurrentAbility, chara: Actor = null) -> int:
	var base: int
	match ab.Damage:
		Ability.D.NONE: base = 0
		Ability.D.WEAK: base = 12
		Ability.D.MEDIUM: base = 24
		Ability.D.HEAVY: base = 48
		Ability.D.SEVERE: base = 96
		Ability.D.CUSTOM: base = int(ab.Parameter)
		Ability.D.WEAPON: base = chara.Weapon.power if chara else Global.bt.CurrentChar.Weapon.power

	if ab.DmgVarience:
		base = int(base * randf_range(0.8, 1.2))

	return base


static func get_complimentaries() -> Array[Ability]:
	var rtn: Array[Ability]
	for i in Global.complimentaries:
		var ability := await get_ability(i)

		if ability != null:
			rtn.append(ability)
		else: push_error("The complimentary Ability ", i, " is invalid")
	return rtn


static func get_ability(ab: String) -> Ability:
	if ResourceLoader.exists("res://database/Abilities/" + ab + ".tres"):
		return await Loader.load_res("res://database/Abilities/" + ab + ".tres")

	if ResourceLoader.exists("res://database/Abilities/Attacks/" + ab + ".tres"):
		return await Loader.load_res("res://database/Abilities/Attacks/" + ab + ".tres")

	return null


static func to_tod_text(x: Event.TOD) -> String:
	match x:
		Event.TOD.MORNING: return "Morning"
		Event.TOD.DAYTIME: return "Daytime"
		Event.TOD.AFTERNOON: return "Afternoon"
		Event.TOD.EVENING: return "Evening"
		Event.TOD.NIGHT: return "Night"

	return "Dark hour"


static func to_tod_icon(x: Event.TOD) -> Texture:
	if ResourceLoader.exists("res://UI/Calendar/" + to_tod_text(x) + ".png"):
		return await Loader.load_res("res://UI/Calendar/" + to_tod_text(x) + ".png")
	else: return null


static func range_360(n1: int, n2: int) -> Array[int]:
	var result: Array[int] = []

	for i in range(n2 - n1):
		result.append(posmod(n1 + i, 360))

	return result


static func make_array_unique(arr: Array) -> void:
	for i in range(-1, arr.size() - 1):
		arr[i] = arr[i].duplicate()


static func mem(Name: StringName) -> Actor:
	return Party.get_member(Name)


static func number_of_party_members() -> int:
	var num := 0

	if Party.has_member_index(0):
		num += 1

	if Party.has_member_index(1):
		num += 1

	if Party.has_member_index(2):
		num += 1

	if Party.has_member_index(3):
		num += 1

	return num


## This is a private function.... In a helper library... that's literally never referenced.
## What does it do? Why is it called quad bezier but checks if the target is on the wall?
## Are you calling this private func from somewhere else?? Then it's not private!
## And if you are, explain what it does! Why is it checking "on wall" ???
## This shouldve just been part of the "global" functin with like a flag if anything!
static func quad_bezier(ti: float, p0: Vector2, p1: Vector2, p2: Vector2, target: Node2D) -> void:
	target.position = _calc_qbezier(ti, p0, p1, p2)


static func global_quad_bezier(ti: float, p0: Vector2, p1: Vector2, p2: Vector2, target: Node2D) -> void:
	target.global_position = _calc_qbezier(ti, p0, p1, p2)


static func _calc_qbezier(ti: float, p0: Vector2, p1: Vector2, p2: Vector2) -> Vector2:
	#Once again, these are all vector2s but named cryptically
	var q0 := p0.lerp(p1, ti)
	var q1 := p1.lerp(p2, ti)
	var r := q0.lerp(q1, ti)
	return r


#Finds an ability of a certain type
static func find_abilities(Char: Actor, type: Ability.TP, ignore_cost := false, targets: Ability.T = Ability.T.ANY) -> Array[Ability]:
	#print("Chosing a ", type, " ability")
	var AblilityList: Array[Ability] = Char.Abilities.duplicate()
	AblilityList.push_front(Char.StandardAttack)
	var Choices: Array[Ability] = []

	for i in AblilityList:
		if (type in i.Types and (targets == Ability.T.ANY or i.Target == targets)):
			if ((i.AuraCost < Char.Aura or i.AuraCost == 0) and i.HPCost < Char.Health) or ignore_cost:
				Choices.push_front(i)
				print(i.name, " AP: ", i.AuraCost, " Targets: ", i.Target)
			else: print("Not enough resources")
	return Choices


static func find_ability(Char: Actor, type: Ability.TP, ignore_cost := false, targets: Ability.T = Ability.T.ANY) -> Ability:
	return find_abilities(Char, type, ignore_cost, targets)[0]


static func is_everyone_fully_healed() -> bool:
	for i in Party.current:
		if !is_instance_valid(i): continue
		if not i.is_fully_healed(): return false

	return true


static func is_mem_healed(chara: Actor) -> bool:
	if !is_instance_valid(chara): return true
	return chara.is_fully_healed()


static func replace_occurence(from: String, what: String, forwhat: String, occurence := 1) -> String:
	var idx := -1

	for i in occurence:
		idx = from.find(what, idx + 1)

	if idx == -1: return from
	return from.substr(0, idx) + forwhat + from.substr(idx + what.length())


static func get_affinity(attacker: Color) -> Affinity:
	var aff := Affinity.new()
	var pres := roundi(remap(attacker.s, 0, 1, 10, 75))
	var hue := roundi(remap(attacker.h, 0, 1, 0, 359))
	#print(in_360(hue-pres/4)," ", in_360(hue+pres/4))
	aff.hue = hue
	aff.color = attacker
	aff.oposing_hue = in_360(hue + 180)
	aff.oposing_range = range_360(aff.oposing_hue - pres / 4, aff.oposing_hue + pres / 4)
	aff.weak_range = range_360(aff.oposing_range[0] - 1 - pres, aff.oposing_range[0] + 1)
	aff.resist_range = range_360(aff.oposing_range[-1] + 1, aff.oposing_range[-1] + 1 + max(pres, 15))
	aff.near_range = range_360(hue - max(pres / 3, 10), hue + max(pres / 3, 10))
	return aff


static func get_power_rating(power: int) -> String:
	if power < 6: return "Useless"
	if power < 12: return "Very weak"
	if power < 18: return "Weak"
	if power < 24: return "Servicable"
	if power < 30: return "Avrage"
	if power < 36: return "Fine"
	if power < 42: return "Kinda good"
	if power < 48: return "Pretty good"
	if power < 54: return "Sharp"
	if power < 60: return "Pretty strong"
	if power < 66: return "Excellent"
	if power < 72: return "Powerful"
	if power < 78: return "Very powerful"
	if power < 84: return "Formidable"
	if power < 90: return "Overpowered"
	if power < 96: return "Godly"
	return "Illegal"


static func get_pronoun(form: String = "they", gender: String = "they") -> String:
	match form:
		"they":
			match gender:
				"he": return "he"
				"she": return "she"
				"it": return "it"
				"they": return "they"

		"them":
			match gender:
				"he": return "him"
				"she": return "her"
				"it": return "it"
				"they": return "them"

		"their":
			match gender:
				"he": return "his"
				"she": return "her"
				"it": return "its"
				"they": return "their"

		"themself":
			match gender:
				"he": return "himself"
				"she": return "herself"
				"it": return "itself"
				"they": return "themself"

	return form


static func world_to_canvas(pos: Vector2, from: CanvasItem = Global.room) -> Vector2:
	return Global.get_viewport().get_screen_transform() * from.get_global_transform_with_canvas() * pos


static func get_ov_sprites(id: String) -> SpriteFrames:
	var nam := id.split(":", false)

	match nam.size():
		1:
			nam.append(nam[0] + "OV")

		2:
			pass

		0, _:
			push_error("Invalid spawn id: " + id)
			return null

	return await Loader.load_res("res://art/OV/" + nam[0] + "/" + nam[1] + ".tres")
