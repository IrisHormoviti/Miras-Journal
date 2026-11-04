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
	var string: String = ""

	for i in conditions:
		if conditions[0] != i:
			string += " or "

		string += "(%s)" % str(i)

	return string


func _icon() -> String:
	return "FileTree"
