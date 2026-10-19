@tool
extends BattleStep
class_name BranchStep

enum Mode {
	CONDITION,
	HIT, ## Includes critical hits.
	CRIT,
	MISS,
}

## Branch on a resource condition or on the current hit outcome.
@export var mode: Mode = Mode.CONDITION:
	set(value):
		mode = value
		notify_property_list_changed()
@export var condition: BattleCondition
## Steps run when the branch matches.
@export var steps: Array[BattleStep] = []
## Steps run when the branch does not match.
@export var else_steps: Array[BattleStep] = []


func run(ctx: ActionSequenceContext) -> void:
	var branch := steps if _matches(ctx) else else_steps
	await ctx.runner.run_steps(branch, ctx)


func _matches(ctx: ActionSequenceContext) -> bool:
	match mode:
		Mode.CONDITION:
			return condition == null or condition.check(ctx)

		Mode.HIT:
			return ctx.roll == HitOutcome.HIT or ctx.roll == HitOutcome.CRIT

		Mode.CRIT:
			return ctx.roll == HitOutcome.CRIT

		Mode.MISS:
			return ctx.roll == HitOutcome.MISS

	return true


func _to_string() -> String:
	match mode:
		Mode.HIT:
			return "On hit"

		Mode.CRIT:
			return "On crit"

		Mode.MISS:
			return "On miss"

	if condition == null:
		return "If a condition"

	return "If %s" % condition


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]

	if mode == Mode.CONDITION:
		visible.append("condition")

	StepEditor.only(property, visible)


func walk() -> Array[BattleStep]:
	var result: Array[BattleStep] = [self]

	for step in steps:
		if step != null:
			result.append_array(step.walk())
	for step in else_steps:
		if step != null:
			result.append_array(step.walk())

	return result


func _icon() -> String:
	return "FileTree"
