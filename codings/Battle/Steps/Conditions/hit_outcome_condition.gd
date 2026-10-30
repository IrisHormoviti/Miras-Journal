@tool
extends BattleCondition
class_name HitOutcomeCondition

@export_flags("Hit", "Crit", "Miss") var outcomes := 7


func check(ctx: ActionSequenceContext) -> bool:
	return(outcomes & (1 << ctx.roll)) != 0


func _init(preset_outcome := 7) -> void:
	outcomes = preset_outcome


func _to_string() -> String:
	var labels := PackedStringArray()

	if outcomes & 1:
		labels.append("hit")

	if outcomes & 2:
		labels.append("crit")

	if outcomes & 4:
		labels.append("miss")

	return " or ".join(labels)


func _icon() -> String:
	return "Dice"
