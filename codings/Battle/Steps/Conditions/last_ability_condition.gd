@tool
extends BattleCondition
class_name LastAbilityCondition

@export var actor: ActorRef
@export var ability_filename: StringName = &""
@export var other: ActorRef


func check(ctx: ActionSequenceContext) -> bool:
	var target := subject(ctx, actor)

	if target == null or target.battle_log.is_empty():
		return false

	var entry: Variant = target.battle_log.back()

	if entry.ability == null or entry.ability.filename != ability_filename:
		return false

	if other != null:
		return entry.target == other.resolve(ctx)

	return true


func _to_string() -> String:
	if str(ability_filename).is_empty():
		return "last ability"

	return "last ability %s" % ability_filename


func _icon() -> String:
	return "History"
