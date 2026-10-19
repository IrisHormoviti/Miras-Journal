extends Resource
class_name ActionSequence

## Ordered steps run from top to bottom.
@export var steps: Array[BattleStep] = []


func is_empty() -> bool:
	return steps.is_empty()


func walk() -> Array[BattleStep]:
	var result: Array[BattleStep] = []

	for step in steps:
		if step == null:
			continue

		result.append_array(step.walk())

	return result
