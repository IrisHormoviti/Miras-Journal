@tool
extends BattleCondition
class_name HasActorCondition

@export var codename: StringName = &""


func check(ctx: ActionSequenceContext) -> bool:
	return ctx.battle.has_actor(codename)


func _to_string() -> String:
	if str(codename).is_empty():
		return "has actor"

	return "has actor %s" % codename


func _icon() -> String:
	return "Node"
