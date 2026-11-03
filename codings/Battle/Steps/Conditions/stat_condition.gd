@tool
extends BattleCondition
class_name StatCondition

## Compares one of an actor's current stats with a value. Health and aura share
## this condition instead of having a class each.

enum Stat {
	HEALTH,
	AURA,
}

const STAT_LABELS := "Health,Aura"


@export_category("Subject")
## Who to check. Defaults to the branch target.
@export var actor: ActorRef
@export_category("Comparison")
## Which stat to compare.
@export var stat: Stat = Stat.HEALTH
## How the stat is compared with [member value].
@export var comparator: BattleCondition.Comparator = BattleCondition.Comparator.GE
## The value to compare the stat against.
@export_range(0, 9999, 1, "or_greater") var value := 0.0
## Compare against the stat's maximum instead of [member value]. Useful for
## checking whether an actor is damaged. Takes priority over [member percent].
@export var compare_to_max := false:
	set(value):
		compare_to_max = value
		notify_property_list_changed()
## Compare the stat as a percentage of its maximum instead of a raw amount.
## Ignored when [member compare_to_max] is enabled.
@export var percent := false:
	set(value):
		percent = value
		notify_property_list_changed()


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)

	var name := str(property.name)

	if name == "stat":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = STAT_LABELS
		return

	# These fields are ignored in "compare to max" mode, so hide them instead
	# of leaving the user to wonder which values matter.
	if compare_to_max and name in ["value", "percent"]:
		property.usage &= ~PROPERTY_USAGE_EDITOR
		return

	if name == "value" and percent:
		property.hint = PROPERTY_HINT_RANGE
		property.hint_string = "0,100,1,or_greater,suffix:%"


func check(ctx: ActionSequenceContext) -> bool:
	var target := subject(ctx, actor)

	if target == null:
		return false

	var current := _current(target)
	var maximum := _maximum(target)
	var expected := value

	if compare_to_max:
		expected = maximum

	if percent and not compare_to_max and maximum > 0:
		current = current / maximum * 100.0

	return compare(current, comparator, expected)


func _current(target: Actor) -> float:
	return float(target.health) if stat == Stat.HEALTH else float(target.aura)


func _maximum(target: Actor) -> float:
	return float(target.max_hp) if stat == Stat.HEALTH else float(target.max_aura)


func _stat_label() -> String:
	return "health" if stat == Stat.HEALTH else "aura"


func _to_string() -> String:
	if compare_to_max:
		return "%s %s %s max %s" % [
			ref_label(actor),
			_stat_label(),
			comparator_label(comparator),
			_stat_label(),
		]

	return "%s %s %s %s%s" % [
		ref_label(actor),
		_stat_label(),
		comparator_label(comparator),
		number_label(value),
		"%" if percent else "",
	]


func _icon() -> String:
	return "Heart" if stat == Stat.HEALTH else "HSlider"
