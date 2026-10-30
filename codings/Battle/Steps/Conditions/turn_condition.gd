@tool
extends BattleCondition
class_name TurnCondition

enum Parity {
	ANY,
	EVEN,
	ODD,
}

@export var turn_min := -1
@export var turn_max := -1
@export var parity: Parity = Parity.ANY


func check(ctx: ActionSequenceContext) -> bool:
	var turn := ctx.battle.Turn

	if turn_min >= 0 and turn < turn_min:
		return false

	if turn_max >= 0 and turn > turn_max:
		return false

	if parity == Parity.EVEN:
		return turn % 2 == 0

	if parity == Parity.ODD:
		return turn % 2 != 0

	return true


func _to_string() -> String:
	if parity != Parity.ANY:
		return "turns %s" % enum_label(Parity, parity)

	if turn_min < 0 and turn_max < 0:
		return "any turn"

	if turn_min < 0:
		return "turn <= %d" % turn_max

	if turn_max < 0:
		return "turn >= %d" % turn_min

	if turn_min == turn_max:
		return "turn %d" % turn_min

	return "turns %d-%d" % [turn_min, turn_max]


func _icon() -> String:
	return "Time"
