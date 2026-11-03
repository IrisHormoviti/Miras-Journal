@tool
extends BattleCondition
class_name GroupSizeCondition

@export_group("Group")
## Which actors to count.
@export var group: ActorGroup.Kind = ActorGroup.Kind.ALLIES
## Include knocked-out actors in the count.
@export var include_dead := false
@export_group("Comparison")
## How the group size is compared with [member value].
@export var comparator: BattleCondition.Comparator = BattleCondition.Comparator.GE
## The number of actors to compare the group size against.
@export_range(0, 64, 1, "or_greater") var value := 0.0


func check(ctx: ActionSequenceContext) -> bool:
	var actors := ActorGroup.resolve(ctx, group, include_dead)
	return compare(float(actors.size()), comparator, value)


func _to_string() -> String:
	return "%s count %s %s" % [
		enum_label(ActorGroup.Kind, group),
		comparator_label(comparator),
		number_label(value),
	]


func _icon() -> String:
	return "Group"
