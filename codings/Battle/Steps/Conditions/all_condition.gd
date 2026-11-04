@tool
extends BattleCondition
class_name AllCondition

@export var conditions: Array[BattleCondition] = []


func check(ctx: ActionSequenceContext) -> bool:
	for condition in conditions:
		if condition != null and not condition.check(ctx):
			return false

	return true


func _to_string() -> String:
	var string: String = ""

	for i in conditions:
		if conditions[0] != i:
			string += " and "

		string += "(%s)" % str(i)

	return string


func _icon() -> String:
	return "FileTree"
