@tool
extends Resource
class_name BattleStep


## Runs this step. Steps that animate or wait may await inside this method.
func run(_ctx: ActionSequenceContext) -> void:
	pass


## Returns every step in this subtree for inspection and validation.
func walk() -> Array[BattleStep]:
	return [self]


## Human readable summary shown on the step card.
func _to_string() -> String:
	return ""


## Editor icon shown on the step card and in the add menu.
func _icon() -> String:
	return "Node"
