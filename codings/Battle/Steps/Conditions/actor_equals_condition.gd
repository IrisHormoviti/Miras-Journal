@tool
extends BattleCondition
class_name ActorEqualsCondition

@export var actor: ActorRef
@export var other: ActorRef


func check(ctx: ActionSequenceContext) -> bool:
	return left(ctx, actor) == right(ctx, other)


func _to_string() -> String:
	return "%s equals %s" % [ref_label(actor), ref_label(other)]


func _icon() -> String:
	return "Node"
