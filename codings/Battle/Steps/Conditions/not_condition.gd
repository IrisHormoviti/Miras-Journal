@tool
extends BattleCondition
class_name NotCondition

@export var condition: BattleCondition


func check(ctx: ActionSequenceContext) -> bool:
	return condition == null or not condition.check(ctx)


func _to_string() -> String:
	if condition == null:
		return "not condition"

	return "not %s" % condition


func _icon() -> String:
	return "FileTree"
