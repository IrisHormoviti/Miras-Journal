extends Resource

class_name Actor

## Represents every character in a battle, as well as all party member data in general.

@export_subgroup("Current")
@export_range(0, 9999) var health: int: set = set_health
@export_range(0, 9999) var aura: int: set = set_aura

@export_category("Info")
##Displayed name of the character
@export var first_name: String = "Name":
	set(x):
		first_name = x
		resource_name = x
##Their Aura color
@export var main_color: Color = Color.WHITE
##Displayed next to their health when focused and in other places
@export var party_icon: Texture
##Used for AI decisions
@export_enum("Unknown", "Attacker", "Mage", "Support", "Tank", "Boss") var actor_class: String
##Used for refrencing the character in code
@export var codename: StringName = &"Actor":
	get():
		if codename == &"Actor":
			codename = first_name.to_pascal_case()

		return codename
##Used in system text, 0: subjective, 1: objective, 2: possessive, 3: -self
@export_enum("it", "he", "she", "they") var pronouns: String = "it"

@export_group("Enemy specific")
##Used to check if the character is an enemy internally
var is_enemy: bool = true
@export var health_bar: bool = false
##Material item that the enemy drops at the end of battle
@export var dropped_item: MaterialItem = null
##Skill Points the party recives for defeating the enemy at the end of battle
@export_range(0, 999, 1, "suffix:SP") var received_sp: int = 5
##What allies will be summoned when calling for help
@export var summoned_allies: Array[Actor]
@export var custom_position: Vector2i = Vector2i.ZERO

@export_group("party specific")
##Used for the Aura gauge, purely cosmetic. If left black, the color will be automatically generated.
@export var secondary_color: Color = Color.BLACK
##Used for textboxes for this character and their box with their stats. If left null, the box will be automatically generated.
@export var character_box_profile: BoxProfile
##Used in the party menu
@export var last_name: String = ""
##Used in the details menu, purely cosmetic
@export var weapon: WeaponItem = preload("res://database/Items/KeyItems/DefaultWeapon.tres")
##Doodles shown in the party menu
@export_file("*.png") var party_page: String
##Artwork shown in the party menu
@export_file("*.png") var render_artwork: String
##Whether the actor is controlled by the player or the AI
@export var controllable: bool = false
@export_range(1, 9999, 1, "suffix:HP") var hp_on_level_up: int = 25
@export_range(1, 9999, 1, "suffix:AP") var ap_on_level_up: int = 10

@export_category("Stats")
@export_range(1, 9999, 1, "suffix:HP") var max_hp: int = 99
@export_range(1, 9999, 1, "suffix:AP") var max_aura: int = 20

##Used for weapon based attacks
@export_range(0, 2) var attack: float = 1
##Used for magic based abilities
@export_range(0, 2) var magic: float = 1
##The higher it is, the less damage this actor takes. 1.5 is neutural.
@export_range(0, 2) var defence: float = 1
##Determines the position in the turn order
@export_range(0, 10) var speed: float = 5

@export_subgroup("Multipliers")
var attack_multiplier: float = 1
var defence_multiplier: float = 1
var magic_multiplier: float = 1
var speed_boost: int = 0

@export_subgroup("Skill points")
@export var skill_level: int = 1
@export var skill_points: int
##The skill points required to reach the next skill level. The 2nd item of the array for example
##is the skill points required to reach skill level 3.
@export var skill_curve: Curve

@export_category("Skills")
##The actors current skill list
@export var abilities: Array[Ability]
##The ability used when the "Attack" button is pressed.
##Can be overriden by the weapon.
@export var standard_attack: Ability = Ability.nothing():
	get():
		if weapon and weapon.attack:
			return weapon.attack

		return standard_attack

##The abilities that can be unlocked by leveling up, party member only
@export var learnable_abilities: Array[Ability]
@export var complimentaries: Array[Ability]
@export var complimentary_list: Dictionary[String, int]
@export var followup_ability: Ability

@export_category("Sprites")
##The sprite used in the overworld when this actor is in the party
@export var ov: String
## Shadow offset for the battle Sprite
@export var ov_shadow_offset: int = 6
##The battle sprites for this actor.
##Some standard animation names include:
##Idle, Hit, Ability, Cast, KnockOut, Entrance, Attack1, Attack2, Item, Command,
##AbilityLoop, ItemLoop, Victory, VictoryLoop
@export var bt: String
##Offset for the battle sprite
@export var offset: Vector2 = Vector2.ZERO
##Whether the shadow sprite should be drawn, preferable for humanoid characters
@export var shadow: bool = false
## Shadow offset for the battle Sprite
@export var bt_shadow_offset: int = 0
## Horizontally flip the battle sprite
@export var flip_h: bool = false
##A scene containing the sound effects for this actor
@export var sound_set: PackedScene:
	get():
		if not sound_set:
			return load("res://sound/Sets/DefaultSoundSet.tscn")

		return sound_set
##When true, the actor will be deleted after being knocked out
@export var disappear: bool = true
## The default amount of glow on the sprite
@export var glow_def: float = 0.3
## The amound of glow when the animations specified in glow_anims are played
@export var glow_special: float = 0.0
## Specify animations where glow_special is used
@export var glow_anims: Array[String] = []
@export var material_override: Material = null

@export_group("Additional parameters")
@export var dont_idle := false
## If true, the character cannot die unless in very low hp
@export var clutch_dmg := false
## Sequence played when dying or clutch in case of cant_die
@export var death_sequence := ""
## If true, the character cannot die, and will always stay at low hp
@export var cant_die := false
@export var ignore_states := false
## Abilities on this target will never miss
@export var cant_dodge := false

enum BtAction {UNSET, ACT, MAGIC, ITEM, ITEM_GIVE, COMMAND}

var next_action: BtAction = BtAction.UNSET
var next_move: Ability = null:
	set(x):
		next_move = x

		if x is not Ability and x != null:
			pass
var next_target: Actor = null
var node: AnimatedSprite2D
var states: Array[State]
var damage_received_this_turn: int = 0
var aura_default: Color = Color.WHITE
var queue_delete := false


class log_entry:
	var turn: int = -1
	var ability: Ability = Ability.nothing()
	var target: Actor = null
var battle_log: Array[log_entry] = [log_entry.new()]


func set_health(x: int) -> void:
	health = x
	health = clampi(health, 0, max_hp)


func add_health(x: int) -> void:
	if x == 0: return
	health += x
	Audio.ui_sound("heal")
	print(first_name + " gains ", x, " Health")
	Global.check.emit()


func set_aura(x: int) -> void:
	aura = x
	aura = clampi(aura, 0, max_aura)


func add_aura(x: int) -> void:
	if x == 0: return
	aura += x
	print(first_name + " gains ", x, " AP")
	Global.check.emit()


func add_SP(x: int) -> void:
	skill_points += x


func damage(dmg: int, limiter := false) -> void:
	var hp := health - dmg

	if hp <= 0:
		if limiter:
			hp = 1
		elif cant_die or (clutch_dmg and health > 15):
			hp = min(health, randf_range(1, 5))
		else: hp = 0
	health = hp


func calc_dmg(power: float, is_magic: bool, attacker: Actor = null) -> int:
	var atk_stat: float
	if attacker == null: atk_stat = 1
	else:
		if is_magic:
			print("Magic stat: ", attacker.magic, " * ", attacker.magic_multiplier)
			atk_stat = attacker.magic * attacker.magic_multiplier
		else:
			atk_stat = attacker.attack * attacker.attack_multiplier
			print("Attack stat: ", attacker.attack, " * ", attacker.attack_multiplier, " = ", atk_stat)

	print("(Power(%.2f) * AttackerStat(%.2f)) / ((Defence(%.2f * %.2f)) + 0.3)" % [power, atk_stat, defence, defence_multiplier])
	return int(max(((power * atk_stat) / ((defence * 1.5 * defence_multiplier) + 0.3)), 1))


## Adds a state to this actor and returns it. When [param await_effect] is true
## the caller waits for the state's presentation (pop number, effect) to finish
## before continuing, so a sequence can pace itself against it.
func add_state(x: Variant, turns := -1, inflicter: Actor = Global.bt.CurrentChar, effect := true, await_effect := false) -> State:
	var state: State
	if x is State:
		# Abilities reference State resources directly, so copy the resource
		# before storing it. Otherwise every actor affected by the same ability
		# would share one State object, including its turn counter and the
		# queue_remove flag that removes the state at the end of a turn.
		state = x.duplicate() as State
		state.queue_remove = false
		# Bare resources (e.g. a Trap referenced directly by an ability) may not
		# have a resource_name, so fall back to the state's display name.
		state.filename = state.resource_name.replace(".tres", "") if state.resource_name != "" else state.name
	else:
		state = (await Loader.load_res("res://database/States/" + x + ".tres")).duplicate()
		state.filename = x

	print(first_name + " recived state " + state.name)
	if not state.is_stat_change and state.name != "Guarding":
		if ignore_states:
			print("But had the ignore_states property")
			return null

	if has_state(state.name) and !state.is_stat_change:
		var prev_state := get_state(state.name)

		if state.turns != -1:
			if state.filename != "KnockedOut":
				prev_state.turns += state.turns
				Global.bt.battle_msg("state_extended", first_name, state.name)
		elif state.name == "Poisoned":
			prev_state.turns *= 2
			Global.bt.battle_msg("poison_intensified", first_name)
		elif state.name == "Confused":
			prev_state.turns = -1
			Global.bt.battle_msg("state_extended", first_name, state.name)

		#else: UI.toast(first_name+" is already "+state.name)
		return prev_state

	if turns != -1:
		state.turns = turns

	state.inflicter = inflicter
	states.append(state)
	if node:
		if await_effect:
			await Global.bt.on_state_add(state, self, effect)
		else:
			Global.bt.on_state_add(state, self, effect)

		if Global.bt.effects.sprite_frames.has_animation(state.name):
			if await_effect:
				await Global.bt.play_effect(state.name, self)
			else:
				Global.bt.play_effect(state.name, self)

	return state


func remove_state(x: Variant) -> void:
	var state: State
	if x is State:
		# An ability passes its own State resource here, which is not the copy
		# stored on this actor, so fall back to matching the state by name.
		state = x if states.has(x) else get_state(x.name)
	else: state = get_state(x)

	if state == null: return
	print(first_name, "'s ", state.name, " state was removed")
	Global.bt.remove_state_effect(state.filename, self)
	states.erase(state)


func has_state(x: String) -> bool:
	#x = x.capitalize()

	for i in states:
		if i.filename == x or i.name == x:
			return true

	return false


func get_state(x: String) -> State:
	for i in states:
		if i.filename == x or i.name == x:
			return i

	return null


func full_heal() -> void:
	health = max_hp
	aura = max_aura


func save_to_dict() -> Dictionary:
	var dict: Dictionary = {
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
		"ComplimentaryList": complimentary_list,
		"clutch_dmg": clutch_dmg,
		"cant_die": cant_die,
		"cant_dodge": cant_dodge,
		"ignore_states": ignore_states,
		"ov": ov,
	}
	return dict


func load_from_dict(dict: Dictionary) -> void:
	for prop in get_property_list():
		var key: String = prop.get("name")

		if dict.has(key):
			set(key, dict.get(key))

	if dict.has("AbilitiesList"):
		abilities.clear()
		for i: String in dict.get("AbilitiesList"):
			if i != "":
				var ab: Ability = await Loader.load_res("res://database/Abilities/" + i + ".tres")

				if ab not in abilities: abilities.append(ab)

	if dict.has("WeaponName") and dict.get("WeaponName") != "":
		weapon = await Item.get_item(dict.get("WeaponName"), &"Key")


func reset_static_info() -> void:
	var og: Actor = load("res://database/Party/" + codename + ".tres")
	attack = og.attack
	defence = og.defence
	magic = og.magic
	sound_set = og.sound_set
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


func is_fully_healed() -> bool:
	return health >= max_hp


func get_abilities(include_compl := true, include_attack := false) -> Array[Ability]:
	var rtn := abilities.duplicate()

	if include_attack: rtn.append(standard_attack)
	if include_compl: rtn.append_array(complimentaries)
	return rtn


func groupped_abilities() -> Array[Array]:
	var rtn: Array[Array]
	for i in get_abilities():
		var found := false

		if i.group != "":
			for j in rtn:
				if j[0].group == i.group:
					j.append(i)
					found = true
					break

		if not found:
			rtn.append([i])

	return rtn


## A shadow for the above artwork
func RenderShadow() -> Texture:
	var render_name: String = render_artwork.split("/")[-1].replace(".png", "")

	if FileAccess.file_exists("res://UI/Party/" + render_name + "Shadow.png"):
		return await Loader.load_res("res://UI/Party/" + render_name + "Shadow.png")
	else: return null


func has_ability(ab: String) -> bool:
	for i in abilities:
		if i.name == ab: return true

	return false


func skill_points_for(level: int) -> int:
	return int(skill_curve.sample(level)) if skill_curve else -1


func get_OV() -> SpriteFrames:
	var path: String = "res://art/OV/" + codename + "/" + codename + "OV" + ov + ".tres"

	if not ResourceLoader.exists(path):
		ov = ""
		push_warning("Couldn't find " + path + ", using fallback")
		return await get_BT()

	return await Loader.load_res(path)


func get_BT() -> SpriteFrames:
	var path: String
	if "/" in bt: path = "res://art/BT/" + bt + ".tres"
	else: path = "res://art/BT/" + codename + "/" + codename + "BT" + bt + ".tres"

	if not ResourceLoader.exists(path):
		if bt != "":
			bt = ""
			return await get_BT()
		else: OS.alert("Invalid BT path, " + path)
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


func get_pronoun(string: String = "they") -> String:
	return Query.get_pronoun(string, pronouns)


func get_attack() -> float:
	return attack * attack_multiplier


func get_magic() -> float:
	return magic * magic_multiplier


func get_defence() -> float:
	return defence * defence_multiplier


func health_ratio() -> float:
	return(float(health) / float(max_hp))


func aura_ratio() -> float:
	return(float(aura) / float(max_aura))
