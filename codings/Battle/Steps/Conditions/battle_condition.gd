@tool
@abstract
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

## Human-readable labels for [enum Comparator], in enum order. Keep this in
## sync with the enum so the inspector never shows bare abbreviations.
const COMPARATOR_LABELS := (
	"Equal to,Not equal to,Greater than,At least,Less than,At most"
)


## Shows readable labels for comparison dropdowns instead of EQ/NE/GT/GE/LT/LE.
## Also refreshes [member resource_name] while the inspector or ResourceSaver
## builds the property list, so saved conditions keep an accurate summary.
func _validate_property(property: Dictionary) -> void:
	var summary := to_string()

	if resource_name != summary:
		resource_name = summary

	if str(property.name) == "comparator":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = COMPARATOR_LABELS


## Returns whether this condition currently passes.
func check(_ctx: ActionSequenceContext) -> bool:
	return true


## Compares two numbers with a comparator, shared by the numeric conditions.
static func compare(one: float, comparison: Comparator, two: float) -> bool:
	match comparison:
		Comparator.EQ:
			return is_equal_approx(one, two)

		Comparator.NE:
			return not is_equal_approx(one, two)

		Comparator.GT:
			return one > two

		Comparator.GE:
			return one >= two

		Comparator.LT:
			return one < two

		Comparator.LE:
			return one <= two

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


## Formats whole numbers without a trailing ".0" in card summaries.
func number_label(number: float) -> String:
	if is_equal_approx(number, roundf(number)):
		return str(int(roundf(number)))

	return str(number)


func comparator_label(comparison: Comparator) -> String:
	match comparison:
		Comparator.EQ:
			return "equals"

		Comparator.NE:
			return "does not equal"

		Comparator.GT:
			return "is greater than"

		Comparator.GE:
			return "is at least"

		Comparator.LT:
			return "is less than"

		Comparator.LE:
			return "is at most"

	return "?"


func enum_label(values: Dictionary, key: int) -> String:
	return str(values.find_key(key)).to_lower().replace("_", " ")


func ref_label(ref: ActorRef) -> String:
	return str(ref) if ref != null else "Target"


func _to_string() -> String:
	return "condition"


func _icon() -> String:
	return "Help"
