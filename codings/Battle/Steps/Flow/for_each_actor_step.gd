@tool
extends BattleStep
class_name ForEachActorStep

@export var group: ActorGroup.Kind = ActorGroup.Kind.TROOP
@export var include_dead := false
@export var exclude_caster := false
@export var steps: Array[BattleStep] = []


func run(ctx: ActionSequenceContext) -> void:
	var previous := ctx.loop_actor
	var actors := ActorGroup.resolve(ctx, group, include_dead)

	for actor in actors:
		if actor == null:
			continue

		if exclude_caster and actor == ctx.caster:
			continue

		ctx.loop_actor = actor
		await ctx.runner.run_steps(steps, ctx)

	ctx.loop_actor = previous


func _to_string() -> String:
	return "For each %s: %d step%s" % [
		str(ActorGroup.Kind.find_key(group)).to_lower().replace("_", " "),
		steps.size(),
		"" if steps.size() == 1 else "s",
	]


func _validate_property(property: Dictionary) -> void:
	StepEditor.only(property, ["group", "include_dead", "exclude_caster"])


func walk() -> Array[BattleStep]:
	var result: Array[BattleStep] = [self]

	for step in steps:
		if step != null:
			result.append_array(step.walk())

	return result


func _icon() -> String:
	return "Loop"
