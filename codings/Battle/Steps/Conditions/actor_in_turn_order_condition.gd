@tool
extends BattleCondition
class_name ActorInTurnOrderCondition

## Checks whether an actor is currently part of the battle's turn order.
@export var actor: ActorRef
@export var present := true


func check(ctx: ActionSequenceContext) -> bool:
	var target := subject(ctx, actor)

	if target == null:
		return not present

	return ctx.battle.TurnOrder.has(target) == present


func _to_string() -> String:
	return "%s %s in the turn order" % [
		ref_label(actor),
		"is" if present else "is not",
	]


func _icon() -> String:
	return "Timer"
