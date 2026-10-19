@tool
extends BattleStep
class_name SequenceStep

enum Mode {
	SEQUENTIAL,
	PARALLEL,
}

@export var mode: Mode = Mode.SEQUENTIAL:
	set(value):
		mode = value
		notify_property_list_changed()
@export var repeat := 1
@export var sequence: ActionSequence


func run(ctx: ActionSequenceContext) -> void:
	if sequence == null:
		return

	for i in maxi(repeat, 1):
		if mode == Mode.SEQUENTIAL:
			await ctx.runner.run_sequence(sequence, ctx)
		else:
			await _run_parallel(ctx)


func _run_parallel(ctx: ActionSequenceContext) -> void:
	var pending := [sequence.steps.size()]

	if pending[0] == 0:
		return

	for step in sequence.steps:
		_run_parallel_step(step, ctx, func() -> void: pending[0] -= 1)

	while pending[0] > 0:
		await ctx.battle.get_tree().process_frame


func _run_parallel_step(step: BattleStep, ctx: ActionSequenceContext, done: Callable) -> void:
	await ctx.runner.run_step(step, ctx)
	done.call()


func _to_string() -> String:
	var count := sequence.steps.size() if sequence != null else 0
	var label := "Parallel" if mode == Mode.PARALLEL else "Sequence"
	return "%s of %d step%s, x%d" % [label, count, "" if count == 1 else "s", maxi(repeat, 1)]


func walk() -> Array[BattleStep]:
	var result: Array[BattleStep] = [self]

	if sequence != null:
		result.append_array(sequence.walk())

	return result


func _icon() -> String:
	return "MainPlay"
