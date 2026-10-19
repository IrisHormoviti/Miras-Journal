@tool
extends BattleStep
class_name MissStep

@export var target := ActorRef.new(ActorRef.Mode.TARGET)
## When false, the next step starts while the miss plays.
@export var wait := false


func run(ctx: ActionSequenceContext) -> void:
	var subject := target.resolve(ctx) if target != null else ctx.target

	if subject == null:
		return

	if wait:
		await ctx.battle.miss(subject)
	else:
		ctx.battle.miss(subject)


func _to_string() -> String:
	var who := str(target) if target != null else "Target"

	return "Miss the %s" % who


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["target", "wait"]

	StepEditor.only(property, visible)


func _icon() -> String:
	return "Warning"
