extends Actor
class_name PartyMember

## A playable party member. Party-only data and progression live here

## Used for textboxes for this character and their box with their stats. If left null, the box will be automatically generated.
@export var character_box_profile: BoxProfile
## Used in the party menu
@export var last_name: String = ""
## Doodles shown in the party menu
@export_file("*.png") var party_page: String
## Artwork shown in the party menu
@export_file("*.png") var render_artwork: String
@export_range(1, 9999, 1, "suffix:HP") var hp_on_level_up: int = 25
@export_range(1, 9999, 1, "suffix:AP") var ap_on_level_up: int = 10

@export_group("Overworld")
## The sprite used in the overworld when this actor is in the party
@export var ov: String
## Shadow offset for the overworld sprite
@export var ov_shadow_offset: int = 6

@export_group("Skills")
## The abilities that can be unlocked by leveling up
@export var learnable_abilities: Array[Ability]
@export var complimentaries: Array[Ability]
@export var complimentary_list: Dictionary[String, int]

@export_subgroup("Progression")
@export var skill_level: int = 1
@export var skill_points: int
## The skill points required to reach the next skill level. The 2nd item of the array for example
## is the skill points required to reach skill level 3.
@export var skill_curve: Curve


func is_party_member() -> bool:
	return true


func get_complimentary_abilities() -> Array[Ability]:
	return complimentaries


func add_SP(x: int) -> void:
	skill_points += x


func save_to_dict() -> Dictionary:
	return {
		"codename": codename,
		"first_name": first_name,
		"last_name": last_name,
		"WeaponName": weapon.filename if not weapon.resource_path.is_empty() else "",
		"controllable": controllable,
		"max_hp": max_hp,
		"max_aura": max_aura,
		"health": health,
		"aura": aura,
		"skill_level": skill_level,
		"skill_points": skill_points,
		"AbilitiesList": get_ability_list(),
		"complimentary_list": complimentary_list,
		"clutch_dmg": clutch_dmg,
		"cant_die": cant_die,
		"cant_dodge": cant_dodge,
		"ignore_states": ignore_states,
		"ov": ov,
	}


func load_from_dict(dict: Dictionary) -> void:
	for prop in get_property_list():
		var key: String = prop.get("name")

		# Complimentary slots need their typed dictionary rebuilt explicitly.
		if key == "complimentary_list":
			continue

		if dict.has(key):
			set(key, dict.get(key))

	if dict.has("complimentary_list"):
		var saved_complimentaries: Dictionary[String, int] = dict.get("complimentary_list")
		complimentary_list.clear()
		for ability_name: String in saved_complimentaries:
			complimentary_list[str(ability_name)] = int(saved_complimentaries[ability_name])

	if dict.has("AbilitiesList"):
		abilities.clear()
		for i: String in dict.get("AbilitiesList"):
			if i != "":
				var ab: Ability = await Loader.load_res("res://database/Abilities/" + i + ".tres")

				if ab not in abilities: abilities.append(ab)

	if dict.has("WeaponName") and dict.get("WeaponName") != "":
		weapon = await Item.get_item(dict.get("WeaponName"), &"Key")


func reset_static_info() -> void:
	var og: PartyMember = load("res://database/Party/" + codename + ".tres")

	if og == null:
		return

	attack = og.attack
	defence = og.defence
	magic = og.magic
	sound_set = og.sound_set
	learnable_abilities = og.learnable_abilities
	party_page = og.party_page


func get_ability_list() -> Array[String]:
	var ab_list: Array[String]
	for i in abilities:
		var ab_name := i.resource_path.replace(".tres", "").replace("res://database/Abilities/", "")

		if not ab_name.is_empty():
			ab_list.append(ab_name)

	return ab_list


## A shadow for the above artwork
func RenderShadow() -> Texture:
	var render_name: String = render_artwork.split("/")[-1].replace(".png", "")

	if FileAccess.file_exists("res://UI/Party/" + render_name + "Shadow.png"):
		return await Loader.load_res("res://UI/Party/" + render_name + "Shadow.png")
	else: return null


func skill_points_for(level: int) -> int:
	return int(skill_curve.sample(level)) if skill_curve else -1


func get_OV() -> SpriteFrames:
	var path: String = "res://art/OV/" + codename + "/" + codename + "OV" + ov + ".tres"

	if not ResourceLoader.exists(path):
		ov = ""
		push_warning("Couldn't find " + path + ", using fallback")
		return await get_BT()

	return await Loader.load_res(path)


func load_complimentaries() -> void:
	complimentaries = []

	for i in complimentary_list:
		if complimentary_list.get(i) > 0:
			complimentaries.append(await Query.get_ability(i))


func level_up_to(lv: int) -> void:
	while skill_level < lv:
		var learnable := find_learnable()
		var rand := randi_range(0, 2)

		if learnable == null: rand = randi_range(0, 1)
		match rand:
			0: max_hp += hp_on_level_up
			1: max_aura += ap_on_level_up
			2: abilities.append(learnable)

		skill_level += 1


func find_learnable() -> Ability:
	var learnable: Ability = null
	var learnables := learnable_abilities.duplicate()
	learnables.reverse()
	for i: Ability in learnables:
		if not i in abilities:
			learnable = i
			continue

	return learnable
