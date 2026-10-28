@tool
extends Resource
class_name BattleCondition

enum Mode {
	ALWAYS,
	FLAG,
	TURN,
	HEALTH,
	STATE,
	LAST_ABILITY,
	PHASE,
	ACTOR_ALIVE,
	HIT_OUTCOME,
	GROUP_SIZE,
	GROUP_STATE,
	STATES_EMPTY,
	SUMMONED_ALLIES,
	ACTOR_EQUALS,
	HAS_ACTOR,
	ABILITY_TYPE,
	ALL,
	ANY,
	NOT,
}

enum Comparator {
	EQ,
	NE,
	GT,
	GE,
	LT,
	LE,
}

enum Parity {
	ANY,
	EVEN,
	ODD,
}

enum GroupMatch {
	ANY,
	ALL,
}

@export var mode: Mode = Mode.ALWAYS:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var other: ActorRef
@export var flag: StringName = &""
@export var value := 0.0
@export var comparator: Comparator = Comparator.GE
@export var compare_to_max := false
@export var percent := false
@export var state: StringName = &""
@export var present := true
@export var ability_filename: StringName = &""
@export var phase: StringName = &""
@export var alive := true
@export_flags("Hit", "Crit", "Miss") var outcomes := 7
@export var group: ActorGroup.Kind = ActorGroup.Kind.ALLIES
@export var include_dead := false
@export var group_match: GroupMatch = GroupMatch.ANY
@export var empty := true
@export var ability_type: Ability.TP = Ability.TP.UNSET
@export var turn_min := -1
@export var turn_max := -1
@export var parity: Parity = Parity.ANY
@export var conditions: Array[BattleCondition] = []
@export var condition: BattleCondition


func check(ctx: ActionSequenceContext) -> bool:
	match mode:
		Mode.ALWAYS:
			return true

		Mode.FLAG:
			return compare(float(Event.get_flag(str(flag))), comparator, value)

		Mode.TURN:
			return _check_turn(ctx)

		Mode.HEALTH:
			return _check_health(ctx)

		Mode.STATE:
			var state_target := _subject(ctx)
			return state_target != null and state_target.has_state(str(state)) == present

		Mode.LAST_ABILITY:
			return _check_last_ability(ctx)

		Mode.PHASE:
			return ctx.battle.get("battle_phase") == phase

		Mode.ACTOR_ALIVE:
			var target := _subject(ctx)

			if target == null or not is_instance_valid(target):
				return not alive

			return(target.health > 0) == alive

		Mode.HIT_OUTCOME:
			return(outcomes & (1 << ctx.roll)) != 0

		Mode.GROUP_SIZE:
			var actors := ActorGroup.resolve(ctx, group, include_dead)
			return compare(float(actors.size()), comparator, value)

		Mode.GROUP_STATE:
			return _check_group_state(ctx)

		Mode.STATES_EMPTY:
			var states_target := _subject(ctx)
			return states_target != null and states_target.states.is_empty() == empty

		Mode.SUMMONED_ALLIES:
			var summon_target := _subject(ctx)
			return summon_target != null and summon_target.summoned_allies.is_empty() == empty

		Mode.ACTOR_EQUALS:
			return _left(ctx) == _right(ctx)

		Mode.HAS_ACTOR:
			return ctx.battle.has_actor(flag)

		Mode.ABILITY_TYPE:
			if ctx.ability == null:
				return false

			return(ability_type in ctx.ability.types) == present

		Mode.ALL:
			for item in conditions:
				if item != null and not item.check(ctx):
					return false

			return true

		Mode.ANY:
			if conditions.is_empty():
				return true

			for item in conditions:
				if item != null and item.check(ctx):
					return true

			return false

		Mode.NOT:
			return condition == null or not condition.check(ctx)

	return true


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


func _check_turn(ctx: ActionSequenceContext) -> bool:
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


func _check_health(ctx: ActionSequenceContext) -> bool:
	var target := _subject(ctx)

	if target == null:
		return false

	var expected := value
	var current := float(target.health)

	if compare_to_max:
		expected = float(target.max_hp)

	if percent:
		current = float(target.health) / float(target.max_hp) * 100.0

	return compare(current, comparator, expected)


func _check_last_ability(ctx: ActionSequenceContext) -> bool:
	var subject := _subject(ctx)

	if subject == null or subject.battle_log.is_empty():
		return false

	var entry: Variant = subject.battle_log.back()

	if entry.ability == null or entry.ability.filename != ability_filename:
		return false

	if other != null:
		return entry.target == other.resolve(ctx)

	return true


func _check_group_state(ctx: ActionSequenceContext) -> bool:
	var actors := ActorGroup.resolve(ctx, group, include_dead)

	if actors.is_empty():
		return false

	for target in actors:
		var has := target.has_state(str(state))

		if group_match == GroupMatch.ANY and has == present:
			return true

		if group_match == GroupMatch.ALL and has != present:
			return false

	return group_match == GroupMatch.ALL


func _subject(ctx: ActionSequenceContext) -> Actor:
	if actor != null:
		return actor.resolve(ctx)
	return ctx.target if ctx.target != null else ctx.caster


func _left(ctx: ActionSequenceContext) -> Actor:
	if actor != null:
		return actor.resolve(ctx)

	return ctx.caster


func _right(ctx: ActionSequenceContext) -> Actor:
	if other != null:
		return other.resolve(ctx)

	return ctx.target


func _to_string() -> String:
	match mode:
		Mode.ALWAYS:
			return "always"

		Mode.FLAG:
			if str(flag).is_empty():
				return "flag"

			return "flag %s %s %s" % [flag, _comparator_label(comparator), str(value)]

		Mode.TURN:
			if parity != Parity.ANY:
				return "turns %s" % _enum_label(Parity, parity)

			if turn_min < 0 and turn_max < 0:
				return "any turn"

			if turn_min < 0:
				return "turn <= %d" % turn_max

			if turn_max < 0:
				return "turn >= %d" % turn_min

			if turn_min == turn_max:
				return "turn %d" % turn_min

			return "turns %d-%d" % [turn_min, turn_max]

		Mode.HEALTH:
			return "%s health %s %s%s" % [
				_ref_label(actor),
				_comparator_label(comparator),
				str(value),
				"%" if percent else "",
			]
		Mode.STATE:
			return "%s %s state %s" % [_ref_label(actor), "has" if present else "lacks", state]

		Mode.LAST_ABILITY:
			if str(ability_filename).is_empty():
				return "last ability"

			return "last ability %s" % ability_filename

		Mode.PHASE:
			if str(phase).is_empty():
				return "phase"

			return "phase %s" % phase

		Mode.ACTOR_ALIVE:
			return "%s %s" % [_ref_label(actor), "alive" if alive else "dead"]

		Mode.HIT_OUTCOME:
			var outcomes_text := PackedStringArray()

			if outcomes & 1:
				outcomes_text.append("hit")

			if outcomes & 2:
				outcomes_text.append("crit")

			if outcomes & 4:
				outcomes_text.append("miss")

			return " or ".join(outcomes_text)

		Mode.GROUP_SIZE:
			return "%s size %s %s" % [
				_enum_label(ActorGroup.Kind, group),
				_comparator_label(comparator),
				str(value),
			]
		Mode.GROUP_STATE:
			return "%s %s %s state %s" % [
				_enum_label(ActorGroup.Kind, group),
				"all" if group_match == GroupMatch.ALL else "any",
				"have" if present else "lack",
				state,
			]
		Mode.STATES_EMPTY:
			return "%s states %s" % [_ref_label(actor), "empty" if empty else "present"]

		Mode.SUMMONED_ALLIES:
			return "%s summons %s" % [_ref_label(actor), "empty" if empty else "present"]

		Mode.ACTOR_EQUALS:
			return "%s equals %s" % [_ref_label(actor), _ref_label(other)]

		Mode.HAS_ACTOR:
			if str(flag).is_empty():
				return "has actor"

			return "has actor %s" % flag

		Mode.ABILITY_TYPE:
			return "ability %s %s" % [
				"is" if present else "is not",
				_enum_label(Ability.TP, ability_type),
			]
		Mode.ALL:
			return "all %d conditions" % conditions.size()

		Mode.ANY:
			return "any %d conditions" % conditions.size()

		Mode.NOT:
			if condition == null:
				return "not condition"

			return "not %s" % condition

	return ""


func _ref_label(ref: ActorRef) -> String:
	return str(ref) if ref != null else "Target"


func _enum_label(values: Dictionary, key: int) -> String:
	return str(values.find_key(key)).to_lower().replace("_", " ")


func _comparator_label(comparison: Comparator) -> String:
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


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]

	match mode:
		Mode.ALWAYS:
			pass

		Mode.FLAG:
			visible.append_array(["flag", "comparator", "value"])

		Mode.TURN:
			visible.append_array(["turn_min", "turn_max", "parity"])

		Mode.HEALTH:
			visible.append_array(["actor", "comparator", "value", "compare_to_max", "percent"])

		Mode.STATE:
			visible.append_array(["actor", "state", "present"])

		Mode.LAST_ABILITY:
			visible.append_array(["actor", "ability_filename", "other"])

		Mode.PHASE:
			visible.append("phase")

		Mode.ACTOR_ALIVE:
			visible.append_array(["actor", "alive"])

		Mode.HIT_OUTCOME:
			visible.append("outcomes")

		Mode.GROUP_SIZE:
			visible.append_array(["group", "include_dead", "comparator", "value"])

		Mode.GROUP_STATE:
			visible.append_array(["group", "include_dead", "state", "present", "group_match"])

		Mode.STATES_EMPTY:
			visible.append_array(["actor", "empty"])

		Mode.SUMMONED_ALLIES:
			visible.append_array(["actor", "empty"])

		Mode.ACTOR_EQUALS:
			visible.append_array(["actor", "other"])

		Mode.HAS_ACTOR:
			visible.append("flag")

		Mode.ABILITY_TYPE:
			visible.append_array(["ability_type", "present"])

		Mode.ALL, Mode.ANY:
			visible.append("conditions")

		Mode.NOT:
			visible.append("condition")

	StepEditor.only(property, visible)
