@tool
extends BattleCondition
class_name PhaseCondition

@export var phase: StringName = &""


func check(ctx: ActionSequenceContext) -> bool:
	return ctx.battle.get("battle_phase") == phase


func _to_string() -> String:
	if str(phase).is_empty():
		return "phase"

	return "phase %s" % phase


func _icon() -> String:
	return "Layers"
