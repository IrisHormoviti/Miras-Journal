@tool
extends BattleStep
class_name HealStep

@export var target: ActorRef
@export var amount: ValueRef


func run(ctx: ActionSequenceContext) -> void:
	var subject := target.resolve(ctx) if target != null else ctx.target

	if subject == null:
		return

	var value := int(round(amount.resolve(ctx))) if amount != null else Query.calc_num(ctx.ability, ctx.caster) * int(ctx.caster.Magic * ctx.caster.MagicMultiplier)
	ctx.battle.heal(subject, value)


func _to_string() -> String:
	var value := str(amount) if amount != null else ""
	var who := str(target) if target != null else "Target"

	if value.is_empty():
		return "Heal %s" % who

	return "Heal %s for %s" % [who, value]


func _icon() -> String:
	return "ThumbsUp"
