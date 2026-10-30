@tool
extends BattleCondition
class_name AnyCondition

@export var conditions: Array[BattleCondition] = []


func check(ctx: ActionSequenceContext) -> bool:
	if conditions.is_empty():
		return true

	for condition in conditions:
		if condition != null and condition.check(ctx):
			return true

	return false


func _to_string() -> String:
	return "any %d conditions" % conditions.size()


func _icon() -> String:
	return "FileTree"
