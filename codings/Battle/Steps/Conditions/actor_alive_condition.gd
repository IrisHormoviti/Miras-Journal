@tool
extends BattleCondition
class_name ActorAliveCondition

@export var actor: ActorRef
@export var alive := true


func check(ctx: ActionSequenceContext) -> bool:
	var target := subject(ctx, actor)

	if target == null or not is_instance_valid(target):
		return not alive

	return(target.health > 0) == alive


func _to_string() -> String:
	return "%s %s" % [ref_label(actor), "alive" if alive else "dead"]


func _icon() -> String:
	return "Heart"
