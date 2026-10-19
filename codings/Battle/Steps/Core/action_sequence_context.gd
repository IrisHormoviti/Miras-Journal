extends RefCounted
class_name ActionSequenceContext

var battle: Battle
var runner: ActionSequenceRunner
var sequence: ActionSequence
var ability: Ability
var item: ItemData
var caster: Actor
var target: Actor
var loop_actor: Actor
var roll: int = HitOutcome.HIT
var home_position := Vector2.ZERO
var aoe_targets: Array[Actor] = []
var is_launcher := false

## Result slots used by steps that need to feed a later message or effect.
var last_actor: Actor
var last_state: State
var last_effect: AnimatedSprite2D
var last_value: float
var named_effects: Dictionary = {}


func duplicate_for_target(new_target: Actor) -> ActionSequenceContext:
	var copy := ActionSequenceContext.new()
	copy.battle = battle
	copy.runner = runner
	copy.sequence = sequence
	copy.ability = ability
	copy.item = item
	copy.caster = caster
	copy.target = new_target
	copy.loop_actor = loop_actor
	copy.roll = roll
	copy.home_position = home_position
	copy.aoe_targets = aoe_targets
	copy.is_launcher = false
	return copy
