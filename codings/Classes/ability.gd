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
}

## Damage type
enum D {
	NONE = 0, ## This abilitiy does no damage
	WEAK = 12, ## 12
	MEDIUM = 24, ## 24
	HEAVY = 48, ## 48
	SEVERE = 96, ## 96
	CUSTOM = -2, ## Specify in parameter
	WEAPON = -1 ## Uses weapon stats
}

##0: Target range
enum T {SELF = 0, ONE_ENEMY = 1, AOE_ENEMIES = 2, ONE_ALLY = 3, AOE_ALLIES = 4, ANY = 5}

@export var name: String
@export_multiline var description: String
@export var Icon: Texture = load("res://art/Icons/Items.tres")
@export var ActionSequence: StringName = &"Default"
#@export var ActionSequenceGraph: SequenceGraph = null
@export var Types: Array[TP] = [TP.UNSET]
@export var Group: String = ""
@export var InflictsState: String = ""
@export var AuraCost: int
@export var HPCost: int
@export var disabled := false
@export var Damage: D = D.NONE
@export var Parameter: float = 0
@export var Target: T = T.SELF
@export var CanTargetDead := false
@export var AOE_Stagger: float = 0
@export var AOE_AdditionalSeq := true

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


static func nothing() -> Ability:
	return ResourceLoader.load("res://database/Abilities/Nothing.tres")
