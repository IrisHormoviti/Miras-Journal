@tool
extends BattleCondition
class_name ActorTurnCondition

## Matches the number of turns a specific actor has taken, rather than the
## battle's global turn counter. Boss patterns like “every other turn” need this
## because the global counter also advances for every party member.

enum Parity {
	ANY,
	EVEN,
	ODD,
}

@export var actor: ActorRef
## First actor turn to match. Negative values ignore the bound.
@export var turn_min := -1
## Last actor turn to match. Negative values ignore the bound.
@export var turn_max := -1
@export var parity: Parity = Parity.ANY


func check(ctx: ActionSequenceContext) -> bool:
	var target := subject(ctx, actor)

	if target == null:
		return false

	var turn := target.turns_taken

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
	var who := ref_label(actor)

	if parity != Parity.ANY:
		return "%s turns %s" % [who, enum_label(Parity, parity)]

	if turn_min < 0 and turn_max < 0:
		return "%s turn" % who

	if turn_min < 0:
		return "%s turn <= %d" % [who, turn_max]

	if turn_max < 0:
		return "%s turn >= %d" % [who, turn_min]

	if turn_min == turn_max:
		return "%s turn %d" % [who, turn_min]

	return "%s turns %d-%d" % [who, turn_min, turn_max]


func _icon() -> String:
	return "Time"
