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

## Damage type
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

@export var name: String
@export_multiline var description: String
@export var Icon: Texture = load("res://art/Icons/Items.tres")
@export var action_sequence: ActionSequence
@export var legacy_action_sequence: StringName = &"Default"
@export_group("AOE only")
@export var aoe_sequence: ActionSequence
@export var AOE_Stagger: float = 0
@export_group("")
#@export var ActionSequenceGraph: SequenceGraph = null
@export var Types: Array[TP] = [TP.UNSET]
@export var Group: String = ""
@export var InflictsState: String = ""
## A trap placed on the target when this ability is used. Traps are States that
## spring when the target is hit. See the "SetTrap" action sequence.
@export var SetsTrap: Trap = null
@export var AuraCost: int
@export var HPCost: int
@export var disabled := false
@export var Damage: D = D.NONE
@export var MakesPhysicalContact := false
@export var Parameter: float = 0
@export var Target: T = T.SELF
@export var CanTargetDead := false
@export var AOE_AdditionalSeq := true
@export var show_cutin := false

@export var ColorSameAsActor := false
@export_color_no_alpha var WheelColor: Color = Color(1, 1, 1, 1)
@export var Callout: bool = true

@export_range(0, 1) var SucessChance: float = 1
@export_range(0, 1) var CritChance: float = 0

@export var RecoverAura: bool = false
@export var DmgVarience: bool = false

var filename: String = "":
	get():
		if filename == "":
			filename = resource_path.replace(".tres", "").replace("res://database/Abilities/", "").replace("Attacks/", "")

		return filename
var remove_item_on_use: ItemData = null


func is_aoe() -> bool:
	if Target == T.AOE_ALLIES or Target == T.AOE_ENEMIES: return true
	else: return false


func is_magic() -> bool:
	return WheelColor == Color.WHITE


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

		if step.power != null and step.power.mode == ValueRef.Mode.WEAPON_POWER:
			return true

	return Damage == D.WEAPON


func damage_hint() -> D:
	if Damage != D.NONE:
		return Damage

	return D.CUSTOM


static func nothing() -> Ability:
	return ResourceLoader.load("res://database/Abilities/Nothing.tres")
