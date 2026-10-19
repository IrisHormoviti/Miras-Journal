@tool
extends BattleStep
class_name RandomStep

@export var options: Array[ActionSequence] = []
## Leave empty for equal odds. Values are relative weights.
@export var weights: Array[float] = []


func run(ctx: ActionSequenceContext) -> void:
	if options.is_empty():
		return

	var chosen := _pick()

	if chosen != null:
		await ctx.runner.run_sequence(chosen, ctx)


func _pick() -> ActionSequence:
	if weights.size() != options.size():
		return options.pick_random()

	var total := 0.0

	for weight in weights:
		total += maxf(weight, 0.0)

	if total <= 0:
		return options.pick_random()

	var roll := randf_range(0.0, total)
	var running := 0.0

	for i in options.size():
		running += maxf(weights[i], 0.0)

		if roll <= running:
			return options[i]

	return options.back()


func _to_string() -> String:
	return "Random of %d option%s" % [options.size(), "" if options.size() == 1 else "s"]


func walk() -> Array[BattleStep]:
	var result: Array[BattleStep] = [self]

	for sequence in options:
		if sequence != null:
			result.append_array(sequence.walk())

	return result


func _icon() -> String:
	return "RandomNumberGenerator"
