@tool
extends BattleCondition
class_name GroupSizeCondition

@export var group: ActorGroup.Kind = ActorGroup.Kind.ALLIES
@export var include_dead := false
@export var comparator: BattleCondition.Comparator = BattleCondition.Comparator.GE
@export var value := 0.0


func check(ctx: ActionSequenceContext) -> bool:
	var actors := ActorGroup.resolve(ctx, group, include_dead)
	return compare(float(actors.size()), comparator, value)


func _to_string() -> String:
	return "%s size %s %s" % [
		enum_label(ActorGroup.Kind, group),
		comparator_label(comparator),
		str(value),
	]


func _icon() -> String:
	return "Group"
