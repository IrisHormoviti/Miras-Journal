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

## Damage type. Deprecated: define the damage scale on the sequence's ValueRef
## instead. Only read here for legacy abilities that have no action sequence.
enum D {
	NONE, ## This abilitiy does no damage
	WEAK, ## 12
	MEDIUM, ## 24
	HEAVY, ## 48
	SEVERE, ## 96
	CUSTOM, ## Specify in parameter
	WEAPON ## Uses weapon stats
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
## The steps that choreograph the ability
@export var action_sequence: ActionSequence
@export_group("AOE only")
## A per-target action_sequence, for AOE abilities
@export var aoe_sequence: ActionSequence
## Delay between running every per target sequence
@export var aoe_stagger: float = 0
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

@export_group("Deprecated")
## Deprecated: add a StateStep to the sequence instead.
@export var InflictsState: String = ""
## Deprecated: add a StateStep in SET_TRAP mode instead.
@export var SetsTrap: Trap = null
## Deprecated: set the scale on the sequence's DamageStep power instead.
@export var Damage: D = D.NONE
## Deprecated: enable contact on the sequence's DamageStep instead.
@export var MakesPhysicalContact := false
## Deprecated: ignored. The launcher and AOE sequences decide this now.
@export var AOE_AdditionalSeq := true
## Deprecated: set the value on the sequence's ValueRef instead.
@export var Parameter: float = 0
## Deprecated: enable variance on the sequence's ValueRef instead.
@export var damage_variance := false
@export var legacy_action_sequence: StringName = &"Default"

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

	if aoe_sequence != null:
		result.append_array(aoe_sequence.walk())

	return result


func primary_damage_step() -> DamageStep:
	for step in all_steps():
		if step is DamageStep:
			return step

	return null


func deals_damage() -> bool:
	return primary_damage_step() != null or Damage != D.NONE


func uses_weapon() -> bool:
	var step := primary_damage_step()

	if step != null:
		if step.magic_mode == DamageStep.MagicMode.PHYSICAL:
			return true

		if step.power != null and step.power.source == ValueRef.Source.DAMAGE:
			if step.power.damage_scale == ValueRef.DamageScale.WEAPON:
				return true

	return Damage == D.WEAPON


func damage_hint() -> D:
	if Damage != D.NONE:
		return Damage

	return D.CUSTOM


## The name of the state this ability applies, from its first add-state step.
## Falls back to the deprecated InflictsState field for abilities with no
## sequence yet. Returns an empty name when the ability applies no state.
func inflicts_state() -> StringName:
	for step in all_steps():
		if step is StateStep:
			var placed := (step as StateStep).added_state()

			if placed != null and not placed.name.is_empty():
				return StringName(placed.name)

	return StringName(InflictsState)


## The trap this ability places, from its first set-trap step. Falls back to the
## deprecated SetsTrap field for abilities with no sequence yet.
func sets_trap() -> Trap:
	for step in all_steps():
		if step is StateStep:
			var placed := (step as StateStep).placed_trap()

			if placed != null:
				return placed

	return SetsTrap


## Whether any damage step hits the target with physical contact. Falls back to
## the deprecated MakesPhysicalContact field for abilities with no sequence yet.
func makes_contact() -> bool:
	for step in all_steps():
		if step is DamageStep and (step as DamageStep).contact:
			return true

	if primary_damage_step() != null:
		return false

	return MakesPhysicalContact


## The damage scale this ability's sequence applies, or null when it deals none.
## Reads the primary DamageStep's ValueRef, falling back to the deprecated
## `Damage` field for abilities that have no sequence yet.
func damage_scale() -> Variant:
	var step := primary_damage_step()

	if step != null and step.power != null and step.power.source == ValueRef.Source.DAMAGE:
		return step.power.damage_scale

	match Damage:
		D.WEAK: return ValueRef.DamageScale.WEAK
		D.MEDIUM: return ValueRef.DamageScale.MEDIUM
		D.HEAVY: return ValueRef.DamageScale.HEAVY
		D.SEVERE: return ValueRef.DamageScale.SEVERE
		D.CUSTOM: return ValueRef.DamageScale.CUSTOM
		D.WEAPON: return ValueRef.DamageScale.WEAPON

	return null


static func nothing() -> Ability:
	return ResourceLoader.load("res://database/Abilities/Nothing.tres")
