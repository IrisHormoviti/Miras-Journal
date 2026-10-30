@tool
extends BattleCondition
class_name HealthCondition

@export var actor: ActorRef
@export var comparator: BattleCondition.Comparator = BattleCondition.Comparator.GE
@export var value := 0.0
@export var compare_to_max := false
@export var percent := false


func check(ctx: ActionSequenceContext) -> bool:
	var target := subject(ctx, actor)

	if target == null:
		return false

	var expected := value
	var current := float(target.health)

	if compare_to_max:
		expected = float(target.max_hp)

	if percent:
		current = float(target.health) / float(target.max_hp) * 100.0

	return compare(current, comparator, expected)


func _to_string() -> String:
	return "%s health %s %s%s" % [
		ref_label(actor),
		comparator_label(comparator),
		str(value),
		"%" if percent else "",
	]


func _icon() -> String:
	return "Heart"
