extends Resource

class_name Actor

## Represents every character in a battle, as well as all party member data in general.

@export_subgroup("Current")
@export_range(0, 9999) var Health: int: set = set_health
@export_range(0, 9999) var Aura: int: set = set_aura

@export_category("Info")
##Displayed name of the character
@export var FirstName: String = "Name":
	set(x):
		FirstName = x
		resource_name = x
##Their Aura color
@export var MainColor: Color = Color.WHITE
##Displayed next to their health when focused and in other places
@export var PartyIcon: Texture
##Used for AI decisions
@export_enum("Unknown", "Attacker", "Mage", "Support", "Tank", "Boss") var ActorClass: String
##Used for refrencing the character in code
@export var codename: StringName = &"Actor":
	get():
		if codename == &"Actor":
			codename = FirstName.to_pascal_case()

		return codename
##Used in system text, 0: subjective, 1: objective, 2: possessive, 3: -self
@export_enum("it", "he", "she", "they") var Pronouns: String = "it"

@export_group("Enemy specific")
##Used to check if the character is an enemy internally
var IsEnemy: bool = true
@export var HealthBar: bool = false
##Material item that the enemy drops at the end of battle
@export var DroppedItem: MaterialItem = null
##Skill Points the party recives for defeating the enemy at the end of battle
@export_range(0, 999, 1, "suffix:SP") var RecivedSP: int = 5
##What allies will be summoned when calling for help
@export var SummonedAllies: Array[Actor]
@export var CustomPosition: Vector2i = Vector2i.ZERO

@export_group("party specific")
##Used for the Aura gauge, purely cosmetic. If left black, the color will be automatically generated.
@export var SecondaryColor: Color = Color.BLACK
##Used for textboxes for this character and their box with their stats. If left null, the box will be automatically generated.
@export var CharacterBoxProfile: BoxProfile
##Used in the party menu
@export var LastName: String = ""
##Used in the details menu, purely cosmetic
@export var Weapon: WeaponItem = preload("res://database/Items/KeyItems/DefaultWeapon.tres")
##Doodles shown in the party menu
@export_file("*.png") var PartyPage: String
##Artwork shown in the party menu
@export_file("*.png") var RenderArtwork: String
##Whether the actor is controlled by the player or the AI
@export var Controllable: bool = false
@export_range(1, 9999, 1, "suffix:HP") var HpOnSLvUp: int = 25
@export_range(1, 9999, 1, "suffix:AP") var ApOnSLvUP: int = 10

@export_category("Stats")
@export_range(1, 9999, 1, "suffix:HP") var MaxHP: int = 99
@export_range(1, 9999, 1, "suffix:AP") var MaxAura: int = 20

##Used for weapon based attacks
@export_range(0, 2) var Attack: float = 1
##Used for magic based abilities
@export_range(0, 2) var Magic: float = 1
##The higher it is, the less damage this actor takes. 1.5 is neutural.
@export_range(0, 2) var Defence: float = 1
##Determines the position in the turn order
@export_range(0, 10) var Speed: float = 5

@export_subgroup("Multipliers")
var AttackMultiplier: float = 1
var DefenceMultiplier: float = 1
var MagicMultiplier: float = 1
var SpeedBoost: int = 0

@export_subgroup("Skill points")
@export var SkillLevel: int = 1
@export var SkillPoints: int
##The skill points required to reach the next skill level. The 2nd item of the array for example
##is the skill points required to reach skill level 3.
@export var SkillCurve: Curve

@export_category("Skills")
##The actors current skill list
@export var Abilities: Array[Ability]
##The ability used when the "Attack" button is pressed.
##Can be overriden by the weapon.
@export var StandardAttack: Ability = Ability.nothing():
	get():
		if Weapon and Weapon.attack:
			return Weapon.attack

		return StandardAttack

##The abilities that can be unlocked by leveling up, party member only
@export var LearnableAbilities: Array[Ability]
@export var Complimentaries: Array[Ability]
@export var ComplimentaryList: Dictionary[String, int]
@export var FollowupAbility: Ability

@export_category("Sprites")
##The sprite used in the overworld when this actor is in the party
@export var OV: String
## Shadow offset for the battle Sprite
@export var OVShadowOffset: int = 6
##The battle sprites for this actor.
##Some standard animation names include:
##Idle, Hit, Ability, Cast, KnockOut, Entrance, Attack1, Attack2, Item, Command,
##AbilityLoop, ItemLoop, Victory, VictoryLoop
@export var BT: String
##Offset for the battle sprite
@export var Offset: Vector2 = Vector2.ZERO
##Whether the shadow sprite should be drawn, preferable for humanoid characters
@export var Shadow: bool = false
## Shadow offset for the battle Sprite
@export var BTShadowOffset: int = 0
## Horizontally flip the battle sprite
@export var FlipH: bool = false
##A scene containing the sound effects for this actor
@export var SoundSet: PackedScene:
	get():
		if not SoundSet:
			return load("res://sound/Sets/DefaultSoundSet.tscn")

		return SoundSet
##When true, the actor will be deleted after being knocked out
@export var Disappear: bool = true
## The default amount of glow on the sprite
@export var GlowDef: float = 0.3
## The amound of glow when the animations specified in GlowAnims are played
@export var GlowSpecial: float = 0.0
## Specify animations where GlowSpecial is used
@export var GlowAnims: Array[String] = []
@export var MaterialOverride: Material = null

@export_group("Additional parameters")
@export var DontIdle := false
## If true, the character cannot die unless in very low hp
@export var ClutchDmg := false
## Sequence played when dying or clutch in case of CantDie
@export var DeathSequence := ""
## If true, the character cannot die, and will always stay at low hp
@export var CantDie := false
@export var IgnoreStates := false
## Abilities on this target will never miss
@export var CantDodge := false

enum BtAction {UNSET, ACT, MAGIC, ITEM, ITEM_GIVE, COMMAND}

var NextAction: BtAction = BtAction.UNSET
var NextMove: Ability = null:
	set(x):
		NextMove = x

		if x is not Ability and x != null:
			pass
var NextTarget: Actor = null
var node: AnimatedSprite2D
var States: Array[State]
var DamageRecivedThisTurn: int = 0
var AuraDefault: Color = Color.WHITE
var queue_delete := false


class log_entry:
	var turn: int = -1
	var ability: Ability = Ability.nothing()
	var target: Actor = null
var BattleLog: Array[log_entry] = [log_entry.new()]


func set_health(x: int) -> void:
	Health = x
	Health = clampi(Health, 0, MaxHP)


func add_health(x: int) -> void:
	if x == 0: return
	Health += x
	Audio.ui_sound("heal")
	print(FirstName + " gains ", x, " Health")
	Global.check.emit()


func set_aura(x: int) -> void:
	Aura = x
	Aura = clampi(Aura, 0, MaxAura)


func add_aura(x: int) -> void:
	if x == 0: return
	Aura += x
	print(FirstName + " gains ", x, " AP")
	Global.check.emit()


func add_SP(x: int) -> void:
	SkillPoints += x


func damage(dmg: int, limiter := false) -> void:
	var hp := Health - dmg

	if hp <= 0:
		if limiter or CantDie or (ClutchDmg and Health > 15):
			hp = min(Health, randf_range(1, 5))
		else: hp = 0
	Health = hp


func calc_dmg(power: float, is_magic: bool, E: Actor = null) -> int:
	var atk_stat: float
	if E == null: atk_stat = 1
	else:
		if is_magic:
			print("Magic stat: ", E.Magic, " * ", E.MagicMultiplier)
			atk_stat = E.Magic * E.MagicMultiplier
		else:
			atk_stat = E.Attack * E.AttackMultiplier
			print("Attack stat: ", E.Attack, " * ", E.AttackMultiplier, " = ", atk_stat)

	print("(Power(%.2f) * AttackerStat(%.2f)) / ((Defence(%.2f * %.2f)) + 0.3)" % [power, atk_stat, Defence, DefenceMultiplier])
	return int(max(((power * atk_stat) / ((Defence * 2 * DefenceMultiplier) + 0.3)), 1))


func add_state(x: Variant, turns := -1, inflicter: Actor = Global.bt.CurrentChar, effect := true) -> State:
	var state: State
	if x is State:
		state = x
		state.filename = state.resource_name.replace(".tres", "")
	else:
		state = (await Loader.load_res("res://database/States/" + x + ".tres")).duplicate()
		state.filename = x

	print(FirstName + " recived state " + state.name)
	if not state.is_stat_change and state.name != "Guarding":
		if IgnoreStates:
			print("But had the IgnoreStates poperty")
			return null

	if has_state(state.name) and !state.is_stat_change:
		var prev_state := get_state(state.name)

		if state.turns != -1:
			if state.filename != "KnockedOut":
				prev_state.turns += state.turns
				Global.bt.battle_msg("state_extended", FirstName, state.name)
		elif state.name == "Poisoned":
			prev_state.turns *= 2
			Global.bt.battle_msg("poison_intensified", FirstName)
		elif state.name == "Confused":
			prev_state.turns = -1
			Global.bt.battle_msg("state_extended", FirstName, state.name)

		#else: Global.toast(FirstName+" is already "+state.name)
		return prev_state

	if turns != -1:
		state.turns = turns

	state.inflicter = inflicter
	States.append(state)
	if node:
		Global.bt.on_state_add(state, self, effect)
		if Global.bt.effects.sprite_frames.has_animation(state.name):
			Global.bt.play_effect(state.name, self)

	return state


func remove_state(x: Variant) -> void:
	var state: State
	if x is State:
		state = x
	else: state = get_state(x)

	if state == null: return
	print(FirstName, "'s ", state.name, " state was removed")
	Global.bt.remove_state_effect(state.filename, self)
	States.erase(state)


func has_state(x: String) -> bool:
	#x = x.capitalize()

	for i in States:
		if i.filename == x or i.name == x:
			return true

	return false


func get_state(x: String) -> State:
	for i in States:
		if i.filename == x or i.name == x:
			return i

	return null


func full_heal() -> void:
	Health = MaxHP
	Aura = MaxAura


func save_to_dict() -> Dictionary:
	var dict: Dictionary = {
		"codename": codename,
		"FirstName": FirstName,
		"LastName": LastName,
		"WeaponName": Weapon.filename if not Weapon.resource_path.is_empty() else "",
		"Controllable": Controllable,
		"MaxHP": MaxHP,
		"MaxAura": MaxAura,
		"Health": Health,
		"Aura": Aura,
		"SkillLevel": SkillLevel,
		"SkillPoints": SkillPoints,
		"AbilitiesList": get_ability_list(),
		"ComplimentaryList": ComplimentaryList,
		"ClutchDmg": ClutchDmg,
		"CantDie": CantDie,
		"CantDodge": CantDodge,
		"IgnoreStates": IgnoreStates,
		"OV": OV,
	}
	return dict


func load_from_dict(dict: Dictionary) -> void:
	for prop in get_property_list():
		var key: String = prop.get("name")

		if dict.has(key):
			set(key, dict.get(key))

	if dict.has("AbilitiesList"):
		Abilities.clear()
		for i: String in dict.get("AbilitiesList"):
			if i != "":
				var ab: Ability = await Loader.load_res("res://database/Abilities/" + i + ".tres")

				if ab not in Abilities: Abilities.append(ab)

	if dict.has("WeaponName") and dict.get("WeaponName") != "":
		Weapon = await Item.get_item(dict.get("WeaponName"), &"Key")


func reset_static_info() -> void:
	var og: Actor = load("res://database/Party/" + codename + ".tres")
	Attack = og.Attack
	Defence = og.Defence
	Magic = og.Magic
	SoundSet = og.SoundSet
	SoundSet = og.SoundSet
	LearnableAbilities = og.LearnableAbilities
	PartyPage = og.PartyPage


func get_ability_list() -> Array[String]:
	var ab_list: Array[String]
	for i in Abilities:
		var ab_name := i.resource_path.replace(".tres", "").replace("res://database/Abilities/", "")

		if not ab_name.is_empty():
			ab_list.append(ab_name)

	return ab_list


func is_fully_healed() -> bool:
	return Health >= MaxHP


func get_abilities(include_compl := true, include_attack := false) -> Array[Ability]:
	var rtn := Abilities.duplicate()

	if include_attack: rtn.append(StandardAttack)
	if include_compl: rtn.append_array(Complimentaries)
	return rtn


func groupped_abilities() -> Array[Array]:
	var rtn: Array[Array]
	for i in get_abilities():
		var found := false

		if i.Group != "":
			for j in rtn:
				if j[0].Group == i.Group:
					j.append(i)
					found = true
					break

		if not found:
			rtn.append([i])

	return rtn


## A shadow for the above artwork
func RenderShadow() -> Texture:
	var render_name: String = RenderArtwork.split("/")[-1].replace(".png", "")

	if FileAccess.file_exists("res://UI/Party/" + render_name + "Shadow.png"):
		return await Loader.load_res("res://UI/Party/" + render_name + "Shadow.png")
	else: return null


func has_ability(ab: String) -> bool:
	for i in Abilities:
		if i.name == ab: return true

	return false


func skill_points_for(level: int) -> int:
	return int(SkillCurve.sample(level)) if SkillCurve else -1


func get_OV() -> SpriteFrames:
	var path: String = "res://art/OV/" + codename + "/" + codename + "OV" + OV + ".tres"

	if not ResourceLoader.exists(path):
		OV = ""
		push_warning("Couldn't find " + path + ", using fallback")
		return await get_BT()

	return await Loader.load_res(path)


func get_BT() -> SpriteFrames:
	var path: String
	if "/" in BT: path = "res://art/BT/" + BT + ".tres"
	else: path = "res://art/BT/" + codename + "/" + codename + "BT" + BT + ".tres"

	if not ResourceLoader.exists(path):
		if BT != "":
			BT = ""
			return await get_BT()
		else: OS.alert("Invalid BT path, " + path)
	return await Loader.load_res(path)


func load_complimentaries() -> void:
	Complimentaries = []

	for i in ComplimentaryList:
		if ComplimentaryList.get(i) > 0:
			Complimentaries.append(await Query.get_ability(i))


func level_up_to(lv: int) -> void:
	while SkillLevel < lv:
		var learnable := find_learnable()
		var rand := randi_range(0, 2)

		if learnable == null: rand = randi_range(0, 1)
		match rand:
			0: MaxHP += HpOnSLvUp
			1: MaxAura += ApOnSLvUP
			2: Abilities.append(learnable)

		SkillLevel += 1


func find_learnable() -> Ability:
	var learnable: Ability = null
	var learnables := LearnableAbilities.duplicate()
	learnables.reverse()
	for i: Ability in learnables:
		if not i in Abilities:
			learnable = i
			continue

	return learnable


func get_pronoun(string: String = "they") -> String:
	return Query.get_pronoun(string, Pronouns)


func get_attack() -> float:
	return Attack * AttackMultiplier


func get_magic() -> float:
	return Magic * MagicMultiplier


func get_defence() -> float:
	return Defence * DefenceMultiplier


func health_ratio() -> float:
	return(float(Health) / float(MaxHP))


func aura_ratio() -> float:
	return(float(Aura) / float(MaxAura))
