@tool
extends BattleStep
class_name ForEachActorStep

@export var group: ActorGroup.Kind = ActorGroup.Kind.TROOP
@export var include_dead := false
@export var exclude_caster := false
## Wait for every actor before moving on instead of running them all at once.
@export var wait := true
@export var steps: Array[BattleStep] = []


func run(ctx: ActionSequenceContext) -> void:
	if wait:
		await _run_sequential(ctx)
	else:
		await _run_parallel(ctx)


func _run_sequential(ctx: ActionSequenceContext) -> void:
	for actor in _actors(ctx):
		await _run_actor(actor, ctx)


func _run_parallel(ctx: ActionSequenceContext) -> void:
	var actors := _actors(ctx)
	var pending := [actors.size()]

	if pending[0] == 0:
		return

	for actor in actors:
		_run_actor_in_background(actor, ctx, func() -> void: pending[0] -= 1)

	while pending[0] > 0:
		await ctx.battle.get_tree().process_frame


func _run_actor_in_background(
	actor: Actor, ctx: ActionSequenceContext, done: Callable
) -> void:
	await _run_actor(actor, ctx)
	done.call()


func _run_actor(actor: Actor, ctx: ActionSequenceContext) -> void:
	var actor_ctx := ctx.duplicate_for_target(actor)
	actor_ctx.loop_actor = actor

	if ctx.ability != null:
		ctx.runner.roll(actor_ctx, actor)

	await ctx.runner.run_steps(steps, actor_ctx)


func _actors(ctx: ActionSequenceContext) -> Array[Actor]:
	var result: Array[Actor] = []

	for actor in ActorGroup.resolve(ctx, group, include_dead):
		if actor == null:
			continue

		if exclude_caster and actor == ctx.caster:
			continue

		result.append(actor)

	return result


func _to_string() -> String:
	var count := steps.size()
	return "For %s %s: %d step%s" % [
		"each" if wait else "all",
		str(ActorGroup.Kind.find_key(group)).to_lower().replace("_", " "),
		count,
		"" if count == 1 else "s",
	]


func _validate_property(property: Dictionary) -> void:
	StepEditor.only(property, ["group", "include_dead", "exclude_caster", "wait"])


func walk() -> Array[BattleStep]:
	var result: Array[BattleStep] = [self]

	for step in steps:
		if step != null:
			result.append_array(step.walk())

	return result


func _icon() -> String:
	return "Loop"
