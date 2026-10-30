@tool
extends BattleStep
class_name BranchStep

## The condition that decides which step list runs. New branches start with a
## hit-outcome condition that matches every outcome, ready to be narrowed down.
@export var condition: BattleCondition = HitOutcomeCondition.new()
## Steps run when the branch matches.
@export var if_steps: Array[BattleStep] = []
## Steps run when the branch does not match.
@export var else_steps: Array[BattleStep] = []


func run(ctx: ActionSequenceContext) -> void:
	var branch := if_steps if _matches(ctx) else else_steps
	await ctx.runner.run_steps(branch, ctx)


func _matches(ctx: ActionSequenceContext) -> bool:
	return condition == null or condition.check(ctx)


func _to_string() -> String:
	if condition == null:
		return "If a condition"

	return "If %s" % condition


func walk() -> Array[BattleStep]:
	var result: Array[BattleStep] = [self]

	for step in if_steps:
		if step != null:
			result.append_array(step.walk())
	for step in else_steps:
		if step != null:
			result.append_array(step.walk())

	return result


func _icon() -> String:
	return "FileTree"
