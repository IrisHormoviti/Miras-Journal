@tool
extends BattleCondition
class_name AbilityTypeCondition

@export var ability_type: Ability.TP = Ability.TP.UNSET
@export var present := true


func check(ctx: ActionSequenceContext) -> bool:
	if ctx.ability == null:
		return false

	return(ability_type in ctx.ability.types) == present


func _to_string() -> String:
	return "ability %s %s" % [
		"is" if present else "is not",
		enum_label(Ability.TP, ability_type),
	]


func _icon() -> String:
	return "Script"
