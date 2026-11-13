extends Actor
class_name PartyMember

## A playable party member. Party-only data and progression live here

## Bounds for a Complimentary Ability's chance to work while it is still being
## practiced. The value rises toward [constant COMPLIMENTARY_MASTER_CHANCE] as
## the remaining successes approach zero, then loses some chance for every step
## the ability's color is away from the actor's own aura color.
const COMPLIMENTARY_BASE_CHANCE := 0.5
const COMPLIMENTARY_MASTER_CHANCE := 0.95
const COMPLIMENTARY_COLOR_PENALTY := 0.3
const COMPLIMENTARY_MIN_CHANCE := 0.05
const COMPLIMENTARY_MAX_CHANCE := 0.95

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
## Equipped Complimentary Abilities, rebuilt from [member complimentary_list].
@export var complimentaries: Array[Ability]
## Per-ability Complimentary progress for this member. See
## [method complimentary_remaining] and the other helpers below for the sign
## convention.
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


## The name to show for an ability in the party and battle menus. A
## Complimentary Ability that still needs practice gets a question mark, so a
## half-learned skill is easy to tell apart from a mastered one.
func ability_display_name(ability: Ability) -> String:
	if ability == null:
		return ""

	if (
		complimentary_list.has(ability.filename)
		and complimentary_remaining(ability.filename) > 0
	):
		return ability.name + "?"

	return ability.name


## The raw signed value stored for a Complimentary Ability. Positive values are
## equipped and count the successes still needed; negative values are benched
## and store -(needed + 1), so -1 is a benched mastered ability.
func complimentary_value(id: String) -> int:
	return int(complimentary_list.get(id, 0))


func is_complimentary_equipped(id: String) -> bool:
	return complimentary_list.has(id) and complimentary_value(id) >= 0


## How many successful casts this member still needs before mastering the
## ability. Zero means mastered.
func complimentary_remaining(id: String) -> int:
	if not complimentary_list.has(id):
		return 0

	var value := complimentary_value(id)
	return value if value >= 0 else absi(value) - 1


## Whether the ability is equipped and still needs practice. Mastered abilities
## and abilities assigned to another member are not training.
func is_complimentary_training(ability: Ability) -> bool:
	if ability == null:
		return false

	var id := ability.filename
	return is_complimentary_equipped(id) and complimentary_remaining(id) > 0


func equip_complimentary(ability: Ability) -> void:
	if ability == null:
		return

	var id := ability.filename
	var remaining := (
		complimentary_remaining(id)
		if complimentary_list.has(id)
		else maxi(1, ability.complimentary_practice)
	)
	complimentary_list[id] = remaining


func unequip_complimentary(ability: Ability) -> void:
	if ability == null:
		return

	var id := ability.filename
	complimentary_list[id] = -(complimentary_remaining(id) + 1)


## Records one successful attempt and returns the number of successes still
## needed. Reaching zero masters the ability for this member only.
func record_complimentary_success(ability: Ability) -> int:
	if ability == null:
		return 0

	var id := ability.filename
	var remaining := maxi(0, complimentary_remaining(id) - 1)
	complimentary_list[id] = remaining
	return remaining


## Chance that a training cast works. Practice makes it more reliable, while a
## color further from the member's aura makes it harder.
func complimentary_success_chance(ability: Ability) -> float:
	if ability == null:
		return 0.0

	var practice := maxi(1, ability.complimentary_practice)
	var remaining := clampi(complimentary_remaining(ability.filename), 0, practice)
	var closeness := 1.0 - float(remaining) / float(practice)
	var chance := lerpf(COMPLIMENTARY_BASE_CHANCE, COMPLIMENTARY_MASTER_CHANCE, closeness)
	chance -= complimentary_color_distance(ability) * COMPLIMENTARY_COLOR_PENALTY
	return clampf(chance, COMPLIMENTARY_MIN_CHANCE, COMPLIMENTARY_MAX_CHANCE)


## How far the ability's wheel color sits from this member's aura color, from
## zero for a matching color to one for the opposite hue. Hue carries most of
## the weight, with saturation as a smaller secondary difference.
func complimentary_color_distance(ability: Ability) -> float:
	if ability == null or ability.color_same_as_actor:
		return 0.0

	var color := ability.wheel_color
	var hue_gap := absf(color.h - main_color.h)
	hue_gap = minf(hue_gap, 1.0 - hue_gap) / 0.5
	var saturation_gap := absf(color.s - main_color.s)
	return clampf(hue_gap * 0.75 + saturation_gap * 0.25, 0.0, 1.0)


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
	var og := load("res://database/Party/" + codename + ".tres") as PartyMember

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
		if not is_complimentary_equipped(i):
			continue

		var ability := await Query.get_ability(i)

		if ability != null:
			complimentaries.append(ability)


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
