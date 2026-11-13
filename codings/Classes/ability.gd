@tool
extends Resource
class_name Ability

## Ability type
enum TP {
	UNSET = 0, ## No type
	CHEAP_ATTACK = 1, ## Attack you can spam
	BIG_ATTACK = 2, ## Attack that uses a lot of resources
	DEFENSIVE = 3, ## Counter, defence, stuff like that
	CURSE = 4, ## Gives a bad state
	HEALING = 5, ## Recovers health
	SUMMON = 6, ## Summons an ally
	AGGRO = 7, ## Makes an enemy attack this actor
	ATK_BUFF = 8, ## Attack up
	MAG_BUFF = 9, ## Magic up
	DEF_BUFF = 10, ## Defence up
	ATK_NERF = 11, ## Attack down
	MAG_NERF = 12, ## Magic down
	DEF_NERF = 13, ## Defence down
	SPEED_CHANGE = 14, ## Modifies speed to the actors favor
	FOLLOW_UP = 15, ## Can be used only after a followup
	COLOR_CHANGE = 16, ## Changes colors
	STATE_RECOVERY = 17, ## Heals a state
	TRAP = 18, ## Sets up a trap on the target
}

##0: Target range
enum T {SELF = 0, ONE_ENEMY = 1, AOE_ENEMIES = 2, ONE_ALLY = 3, AOE_ALLIES = 4, ANY = 5}

## Display name
@export var name: String
## Description in the menu
@export_multiline var description: String
## Display icon, use an instance of Items.tres
@export var icon: Texture = load("res://art/Icons/Items.tres")
## Action sequence steps
@export_color_no_alpha var wheel_color: Color = Color(1, 1, 1, 1)
## Ignore wheel_color and just use the Actor's Color
@export var color_same_as_actor := false
## Who this ability can target
@export var target: T = T.SELF
## The steps that choreograph the ability. Use a ForEachActorStep to target
## every actor of an AOE.
@export var action_sequence: ActionSequence
@export_category("Cost")
## AP used to cast this ability
@export_custom(PROPERTY_HINT_NONE, "suffix:AP") var aura_cost: int
## HP used to cast this ability
@export_custom(PROPERTY_HINT_NONE, "suffix:HP") var hp_cost: int
@export_category("RNG")
## The chance of not missing
@export_range(0, 1) var success_chance: float = 1
## The chance of a critical hit. Critical can mean diffrent things,
## It's interprated by the action sequence
@export_range(0, 1) var crit_chance: float = 0
@export_category("Metadata")
## Ability categorization, used for AI logic
@export var types: Array[TP] = [TP.UNSET]
## Abilities of the same group name are groupped togeather in the menu 
@export var group: String = ""
## This ability can target dead actors. Useful for healing.
@export var can_target_dead := false
## Show a cut-in of the caster before casting
@export var show_cutin := false
## Show callout text before casting. Should be off for standard attacks
@export var callout: bool = true
## When dealing damage, aura is recovered
@export var recover_aura: bool = false

@export_category("Complimentary")
## Successful casts needed to master this ability for a party member. Only used
## by Complimentary Abilities. The member starts at this value when they equip
## the ability, and each successful practice cast lowers it by one.
@export_range(1, 99, 1) var complimentary_practice := 3

@export_storage var disabled := false

var filename: String = "":
	get():
		if filename == "":
			filename = resource_path.replace(".tres", "").replace("res://database/Abilities/", "").replace("Attacks/", "")

		return filename
var remove_item_on_use: ItemData = null


func is_aoe() -> bool:
	if target == T.AOE_ALLIES or target == T.AOE_ENEMIES: return true
	else: return false


func is_magic() -> bool:
	return wheel_color == Color.WHITE


func all_steps() -> Array[BattleStep]:
	var result: Array[BattleStep] = []

	if action_sequence != null:
		result.append_array(action_sequence.walk())

	return result


func primary_damage_step() -> DamageStep:
	for step in all_steps():
		if step is DamageStep:
			return step

	return null


func primary_heal_step() -> HealStep:
	for step in all_steps():
		if step is HealStep:
			return step

	return null


func deals_damage() -> bool:
	return primary_damage_step() != null


func uses_weapon() -> bool:
	var step := primary_damage_step()

	if step == null:
		return false

	if step.magic_mode == DamageStep.MagicMode.PHYSICAL:
		return true

	return (
		step.power != null
		and step.power.source == ValueRef.Source.DAMAGE
		and step.power.damage_scale == ValueRef.DamageScale.WEAPON
	)


## The name of the state this ability applies, from its first add-state step.
## Returns an empty name when the ability applies no state.
func inflicts_state() -> StringName:
	for step in all_steps():
		if step is StateStep:
			var placed := (step as StateStep).added_state()

			if placed != null and not placed.name.is_empty():
				return StringName(placed.name)

	return &""


## Whether any damage step hits the target with physical contact.
func makes_contact() -> bool:
	for step in all_steps():
		if step is DamageStep and (step as DamageStep).contact:
			return true

	return false


## The damage scale this ability's sequence applies, or null when it deals none.
func damage_scale() -> Variant:
	var step := primary_damage_step()

	if step != null and step.power != null and step.power.source == ValueRef.Source.DAMAGE:
		return step.power.damage_scale

	return null


static func nothing() -> Ability:
	return ResourceLoader.load("res://database/Abilities/Nothing.tres")
