@tool
extends BattleCondition
class_name AlwaysCondition

## A condition that always passes.


func check(_ctx: ActionSequenceContext) -> bool:
	return true


func _to_string() -> String:
	return "always"


func _icon() -> String:
	return "StatusSuccess"
