extends Resource
class_name State

@export var name: String
@export_multiline var description: String
@export var removed_on_battle_end := true
@export var parameter := 0.0
## If not -1, the state will be removed after the specified turns
@export var turns: int = -1
@export var icon: Texture
@export var color: Color = Color.WHITE
@export_enum("None", "Guard", "Hurt") var pose: String = "None"
@export var weak_mult := 1.0
@export var magic_dmg_mult := 1.0
@export var weapon_dmg_mult := 1.0
@export var is_stat_change := false
@export_group("Sequences")
## Runs after the state is added to an actor. The owner is the sequence target,
## and the state's inflicter is the caster.
@export var on_add: ActionSequence
## Runs after the state is removed from an actor. The owner is both the caster
## and the target.
@export var on_remove: ActionSequence
## Runs at the start of the owner's turn, after the turn counter is decremented.
## The owner is both the caster and the target.
@export var on_turn: ActionSequence
var inflicter: Actor = null
var queue_remove := false
var filename := ""
