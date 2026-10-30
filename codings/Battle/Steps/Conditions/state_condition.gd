@tool
extends BattleCondition
class_name StateCondition

@export var actor: ActorRef
@export var state: StringName = &""
@export var present := true


func check(ctx: ActionSequenceContext) -> bool:
	var target := subject(ctx, actor)

	if target == null:
		return false

	return target.has_state(str(state)) == present


func _to_string() -> String:
	return "%s %s state %s" % [
		ref_label(actor),
		"has" if present else "lacks",
		state,
	]


func _icon() -> String:
	return "CheckBox"
