extends Resource

class_name ItemData

## Displayed name of this item
@export var Name: String = " - None - "

@export_storage var filename: String = "Invalid filename":
	get():
		if not resource_path.is_empty():
			filename = resource_path.get_file().replace(".tres", "")

		return filename

## Displayed description of this item in the menu.
## Specific words are colorized
@export_multiline var Description: String = "One that does not exit"

## The inventory this item belongs to
## Note that this should match which folder the item is inside
@export_enum("Key", "Con", "Mat", "Bti") var ItemType: String = ""

## The icon of this item. 
## Make sure the atlas used is a unique instance
@export var Icon: Texture = load("res://art/Icons/Items.tres")

## Instead of "X in bag" when having multiple in the bag,
## say "X uses remain".
@export var QuantityMeansUses := false

## How many of this item should be recieved when getting it.
@export var AmountOnAdd := 1

enum U {
	NONE, ## This item cannot be used
	INSPECT, ## A textbox should appear when inspecting this item in the inventory
	CUSTOM, ## A custom function is defined in the item manager
	HEALING, ## This item can be used for healing outside battle
	SPELL, ## Dummy
	STATE_HEAL, ## This item removed a state from an ally
	BUFF_ATK, ## Buffs an ally's attack
	DEBUFF_ATK ## DeBuffs an enemy's attack
}

@export_group("Uses")
## What this item is used for
@export var Use: U
## Should it appear in the battle inventory?
@export var UsedInBattle := false
enum T {SELF, ONE_ALLY, AOE_ALLIES}
## Who should be targeted when this item is used in the overworld
@export var OvTarget: T = T.ONE_ALLY
## An ability for when this item is used in battle
@export var BattleEffect: Ability
## Used for various things, like the amount of healing in a healing item
@export var Parameter: String


func get_artwork() -> Texture:
	var path := "res://art/Items/"+filename+".png"

	if ResourceLoader.exists(path):
		return await Loader.load_res(path)
	else:
		return null
