@tool
extends BattleCondition
class_name ValueCondition

## Compares a resolved value with a fixed number. Use this for checks that do
## not fit a stat, such as how much damage an actor has taken this turn.
@export var value: ValueRef
@export var comparator: BattleCondition.Comparator = BattleCondition.Comparator.EQ
@export var other := 0.0


func check(ctx: ActionSequenceContext) -> bool:
	var current := value.resolve(ctx) if value != null else 0.0
	return compare(current, comparator, other)


func _to_string() -> String:
	return "%s %s %s" % [
		str(value) if value != null else "value",
		comparator_label(comparator),
		number_label(other),
	]


func _icon() -> String:
	return "Compare"
