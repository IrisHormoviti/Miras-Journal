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
## A trap interrupted this context's sequence, so it can't deal more damage.
var interrupted := false
## True while a State's own add/remove/turn sequence is running. State steps
## use this to fall back to the state that triggered the sequence.
var state_sequence := false
var home_position := Vector2.ZERO

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
	copy.state_sequence = state_sequence
	copy.home_position = home_position
	copy.interrupted = interrupted
	copy.last_actor = last_actor
	copy.last_state = last_state
	copy.last_effect = last_effect
	copy.last_value = last_value
	copy.named_effects = named_effects.duplicate()
	return copy
