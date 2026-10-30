@tool
extends BattleCondition
class_name SummonedAlliesCondition

@export var actor: ActorRef
@export var empty := true


func check(ctx: ActionSequenceContext) -> bool:
	var target := subject(ctx, actor)
	return target != null and target.summoned_allies.is_empty() == empty


func _to_string() -> String:
	return "%s summons %s" % [ref_label(actor), "empty" if empty else "present"]


func _icon() -> String:
	return "SkeletonPreview"
