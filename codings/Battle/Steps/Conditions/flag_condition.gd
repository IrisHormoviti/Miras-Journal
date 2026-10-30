@tool
extends BattleCondition
class_name FlagCondition

## A flag expression evaluated by [method Event.f], for example
## "Event/BossPhase >= 2" or "Event/GuardianDown = 1".

@export var expression: StringName = &""


func check(_ctx: ActionSequenceContext) -> bool:
	if expression.is_empty():
		return true

	return Event.f(expression)


func _to_string() -> String:
	if expression.is_empty():
		return "a flag"

	return "flag %s" % expression


func _icon() -> String:
	return "Flag"
