extends Resource
class_name BattleSequence

## The enemies present in the battle as Actor Resources. These are duplicated when loaded so any changes to their resource doesn't affect other instances of them.
@export var Enemies: Array[Actor]
## Items to get at the end of the battle
@export var AdditionalItems: Array[ItemData]
## The music configuration for this fight
@export var Music: BattleMusicSet = preload("res://sound/Sets/Lost in the Ruins - Set.tres")
## Whether the battle background should be treated as an actual location on the map or a background only for this battle.
## If false, the player will be positioned where the party leader was in battle, if true they will be positioned where they were before.
## It's recommended to turn on `Detransition` along with this.
@export var UseBackground := false
## Show this image behind the battle scene
@export var BattleBack: Texture
## The position on the map the battle takes place
@export var ScenePosition: Vector2 = Vector2.ZERO
## Show a screen wipe when the battle starts.
@export var Transition: bool = true
## Show a screen wipe after the battle is over
@export var Detransition: bool = false
@export var ReturnControl: bool = true
@export var EscPosition: Vector2i
@export var PositionSameAsPlayer := false
## Whether the Escape button should be usable
@export var CanEscape := true
@export var DeleteAttacker := true
@export var EntranceSequence := ""
@export var EntranceBanter := ""
@export var EntranceBanterIsPassive := true
@export var VictorySequence := ""
@export var VictoryBanter := ""
@export var VictoryText := "Victory"
@export var DefeatSequence := ""
## Override the party with the specified Array of IDs
@export var PartyOverride: PackedStringArray = []
@export var Events: Array[BattleEvent] = []


func call_events() -> void:
	for i in Events:
		if i.check():
			await i.run()


func check_events() -> bool:
	for i in Events:
		if i.check(): return true

	return false


func reset_events(force := false) -> void:
	for i in Events:
		if i == null:
			push_error("There's a null battle event, you better remove that")
			continue

		if i.repeatable or force:
			i.ran_this_turn = false
