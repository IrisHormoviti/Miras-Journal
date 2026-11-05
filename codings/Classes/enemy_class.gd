extends Actor
class_name Enemy

## An enemy combatant. Reward, health-bar and scripted-turn data live here

@export var health_bar: bool = false
## Material item that the enemy drops at the end of battle
@export var dropped_item: MaterialItem = null
## Skill Points the party recives for defeating the enemy at the end of battle
@export_range(0, 999, 1, "suffix:SP") var received_sp: int = 5
## What allies will be summoned when calling for help
@export var summoned_allies: Array[Enemy]
@export var custom_position: Vector2i = Vector2i.ZERO
## Optional ability used for this enemy's follow-up after a scripted turn.
@export var followup_ability: Ability
## Optional sequence that drives this actor's whole turn instead of the AI.
## Useful for bosses that take several actions or follow a scripted pattern.
@export var turn_sequence: ActionSequence

@export_group("Beastiary")
## This enemy can be analyzed to be added to the journal
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var has_beastiary: bool = false
## The text shown.
@export_multiline var description: String
@export var doodle: Texture
@export_enum("Normal", "Strong", "Weak") var impression: String = "Normal"
