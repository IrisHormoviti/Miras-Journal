@tool
extends BattleCondition
class_name ChanceCondition

## Rolls a random percentage each time it is checked. Use this for saving
## throws and other one-shot random branches.
@export_range(0, 100, 1, "suffix:%") var chance := 50.0:
	set(value):
		chance = value
		notify_property_list_changed()
## Use the subject's remaining health percentage instead of the fixed chance.
@export var use_health_ratio := false:
	set(value):
		use_health_ratio = value
		notify_property_list_changed()
@export var actor: ActorRef


func check(ctx: ActionSequenceContext) -> bool:
	var percent := chance

	if use_health_ratio:
		var target := subject(ctx, actor)

		if target == null or target.max_hp <= 0:
			return false

		percent = float(target.health) / float(target.max_hp) * 100.0

	return randf() * 100.0 <= percent


func _to_string() -> String:
	if use_health_ratio:
		return "%s health chance" % ref_label(actor)

	return "%s%% chance" % number_label(chance)


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)

	var name := str(property.name)

	if name == "chance" and use_health_ratio:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif name == "actor" and not use_health_ratio:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _icon() -> String:
	return "RandomNumberGenerator"
