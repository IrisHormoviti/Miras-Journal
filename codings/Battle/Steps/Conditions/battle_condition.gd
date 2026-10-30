@tool
extends Resource
class_name BattleCondition

## Base class for the conditions a BranchStep can test. Each concrete condition
## lives in its own subclass and owns only the fields it needs.

enum Comparator {
	EQ,
	NE,
	GT,
	GE,
	LT,
	LE,
}


## Returns whether this condition currently passes.
func check(_ctx: ActionSequenceContext) -> bool:
	return true


## Compares two numbers with a comparator, shared by the numeric conditions.
static func compare(left: float, comparison: Comparator, right: float) -> bool:
	match comparison:
		Comparator.EQ:
			return is_equal_approx(left, right)

		Comparator.NE:
			return not is_equal_approx(left, right)

		Comparator.GT:
			return left > right

		Comparator.GE:
			return left >= right

		Comparator.LT:
			return left < right

		Comparator.LE:
			return left <= right

	return false


## Resolves the condition's subject, defaulting to the branch target.
func subject(ctx: ActionSequenceContext, actor: ActorRef) -> Actor:
	if actor != null:
		return actor.resolve(ctx)

	return ctx.target if ctx.target != null else ctx.caster


## The left-hand actor for comparisons, defaulting to the caster.
func left(ctx: ActionSequenceContext, actor: ActorRef) -> Actor:
	return actor.resolve(ctx) if actor != null else ctx.caster


## The right-hand actor for comparisons, defaulting to the branch target.
func right(ctx: ActionSequenceContext, other: ActorRef) -> Actor:
	return other.resolve(ctx) if other != null else ctx.target


func comparator_label(comparison: Comparator) -> String:
	match comparison:
		Comparator.EQ:
			return "="

		Comparator.NE:
			return "!="

		Comparator.GT:
			return ">"

		Comparator.GE:
			return ">="

		Comparator.LT:
			return "<"

		Comparator.LE:
			return "<="

	return "?"


func enum_label(values: Dictionary, key: int) -> String:
	return str(values.find_key(key)).to_lower().replace("_", " ")


func ref_label(ref: ActorRef) -> String:
	return str(ref) if ref != null else "Target"


func _to_string() -> String:
	return "condition"


func _icon() -> String:
	return "Help"
