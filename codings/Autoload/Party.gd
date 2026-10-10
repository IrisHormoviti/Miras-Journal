extends Node

## Array of the current party members, has to be 4
var current: Array[Actor] = [null]
## Data for all party members (Outside of the party too)
var members: Array[Actor] = []

var Leader: Actor:
	get(): return current[0] if current.size() > 0 else null
	set(x): current[0] = x

var Member1: Actor:
	get(): return current[1] if current.size() > 1 else null
	set(x): current[1] = x

var Member2: Actor:
	get(): return current[2] if current.size() > 2 else null
	set(x): current[2] = x

var Member3: Actor = null:
	get(): return current[3] if current.size() > 3 else null
	set(x): current[3] = x


func _init() -> void:
	members.clear()

	for i in ResourceLoader.list_directory("res://database/Party"):
		var file: Resource = load("res://database/Party/" + i)

		if file is Actor:
			members.append(file.duplicate())

	reset_party()


func get_member(codename: StringName) -> Actor:
	for i in members:
		if i.codename == codename: return i

	push_warning("No party member with the name " + codename + " was found")
	return null


func reset_party() -> void:
	set_to([&"Mira"])


func reset_all_members() -> void:
	var current_party := get_strarr()

	_init()
	for i in range(-1, members.size() - 1):
		members[i] = load("res://database/Party/" + members[i].codename + ".tres").duplicate(true)

	set_to(current_party)


func has_member_index(n: int) -> bool:
	return size() > n


func make_unique() -> void:
	if Leader != null: Leader = Leader.duplicate()
	if Member1 != null: Member1 = Member1.duplicate()
	if Member2 != null: Member2 = Member2.duplicate()
	if Member3 != null: Member3 = Member3.duplicate()


func set_to(p: PackedStringArray) -> void:
	if p.is_empty(): p = [&"Mira", &"", &"", &""]
	current.clear()

	for i in p:
		if not i.is_empty():
			current.append(get_member(i))

	Global.check.emit()


func get_strarr() -> Array[StringName]:
	var arr: Array[StringName] = [&"", &"", &"", &""]

	if has_member_index(0): arr[0] = Leader.codename
	if has_member_index(1): arr[1] = Member1.codename
	if has_member_index(2): arr[2] = Member2.codename
	if has_member_index(3): arr[3] = Member3.codename
	return arr


func get_member_index(num: int) -> Actor:
	match num:
		0: return Leader
		1: return Member1
		2: return Member2
		3: return Member3

	return null


func member_index(mem: Actor) -> int:
	return current.find(mem)


func overwrite_member(num: int, actor: Actor) -> void:
	current[num] = actor


func add(member: String) -> void:
	var actor := get_member(member)
	if actor == null: return
	if actor in current: return

	# `current` is a fixed 4-slot array; fill the first empty slot instead of
	# appending, which would overwrite the Leader slot when the array is short.
	for i in 4:
		if i >= current.size():
			current.append(actor)
			break

		if current[i] == null:
			current[i] = actor
			break

	Global.check.emit()
	print(member, " joins the party at position ", member_index(actor))


func member_name(x: int) -> String:
	if has_member_index(x): return current[x].FirstName
	return "Nobody"


func has_member(mem: String) -> bool:
	for i in current:
		if i != null and i.codename == mem: return true

	return false


func size() -> int:
	var count := 0

	for i in current:
		if i != null: count += 1

	return count


func make_everyone_controllable() -> void:
	for i in current:
		if i: i.Controllable = true

## Complimentary abilities available
var complimentaries: Array[String] = []


func heal_party() -> void:
	for i in current:
		if i: i.full_heal()

	for i in members:
		i.full_heal()


func add_test_state(chara: Actor) -> void:
	for i in ResourceLoader.list_directory("res://database/States/"):
		var state: String = i.replace(".tres", "")
		var ab: Ability = load("res://database/Abilities/Debug/TestState.tres").duplicate()
		ab.name += state
		ab.InflictsState = state
		chara.Abilities.append(ab)


func unlock_all_abilities() -> void:
	for mem in members:
		for ab in mem.LearnableAbilities:
			if ab not in mem.Abilities: mem.Abilities.append(ab)


func give_every_ability() -> void:
	for i in ResourceLoader.list_directory("res://database/Abilities/"):
		var ab: Ability = load("res://database/Abilities/" + i).duplicate()
		Leader.Abilities.append(ab)


func add_complimentary(ability: String, from_name: String = "Mira Levenor", popup := true) -> void:
	if popup:
		var scenepack: PackedScene = load("res://UI/LevelUp/Levelup.tscn")
		var scene: Node = scenepack.instantiate()
		UI.add_child(scene)
		await Event.wait()
		scene.get_node("Levelup").got_complimentary(await Query.get_ability(ability), from_name)
		await scene.get_node("Levelup").closed

	if ability not in complimentaries:
		complimentaries.append(ability)


func use_ability_overworld(ab: Ability, user: Actor) -> void:
	get_viewport().gui_release_focus()
	if Ability.TP.HEALING in ab.Types:
		await Hud.choose_member(ab, user)
