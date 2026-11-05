@tool
extends BattleStep
class_name QueueMoveStep

## Saves a move for an actor to take on its next turn. The battle consumes the
## saved move when that actor's turn starts, so a sequence can set up a
## follow-up without running it immediately.

@export var actor: ActorRef
@export var ability: Ability
## Who the actor will aim at. Leave empty to keep the target the actor would
## otherwise choose.
@export var target: ActorRef
## The turn animation the actor plays for the queued move.
@export var action: Actor.BtAction = Actor.BtAction.ACT


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.caster

	if subject == null:
		return

	subject.next_action = action

	if ability != null:
		subject.next_move = ability

	if target != null:
		subject.next_target = target.resolve(ctx)


func _to_string() -> String:
	var who := str(actor) if actor != null else "Caster"
	var move := ability.name if ability != null else "their next move"

	if target == null:
		return "Queue %s for %s" % [move, who]

	return "Queue %s for %s on %s" % [move, who, target]


func _validate_property(property: Dictionary) -> void:
	StepEditor.only(property, ["actor", "action", "ability", "target"])


func _icon() -> String:
	return "Timer"
