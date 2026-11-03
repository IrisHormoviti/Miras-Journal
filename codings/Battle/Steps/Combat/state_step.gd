@tool
extends BattleStep
class_name StateStep

enum Mode {
	ADD,
	REMOVE,
	CLEAR,
	SET_TRAP,
	AURA_OVERWRITE,
	SET_TURNS,
	REMOVE_RANDOM,
	REMOVE_QUEUED,
	ADD_TURNS,
}

@export var mode: Mode = Mode.ADD:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef = ActorRef.new(ActorRef.Mode.TARGET)
@export var state: State
@export var turns := -1
@export var silent := false
@export var wait := true
@export var trap: Trap
@export var color: ColorRef


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.target

	if subject == null:
		return

	match mode:
		Mode.ADD:
			var place: Variant = _state(ctx)
			ctx.last_state = await subject.add_state(place, turns, ctx.caster, not silent, wait, ctx)

		Mode.REMOVE:
			await subject.remove_state(_state(ctx), ctx, true)

		Mode.CLEAR:
			await ctx.battle.clear_states(subject)

		Mode.SET_TRAP:
			ctx.last_state = await ctx.battle.apply_trap(trap, subject, ctx.caster, wait)

		Mode.AURA_OVERWRITE:
			var overwrite := color.resolve(ctx) if color != null else subject.main_color
			await ctx.battle.aura_overwrite(subject, overwrite, turns)

		Mode.SET_TURNS:
			var current := subject.get_state(_state_name(ctx))

			if current != null:
				current.turns = turns

		Mode.ADD_TURNS:
			var current := subject.get_state(_state_name(ctx))

			if current != null:
				current.turns += turns

		Mode.REMOVE_RANDOM:
			if not subject.states.is_empty():
				var random_state: State = subject.states.pick_random()
				ctx.last_state = random_state
				await subject.remove_state(random_state, ctx, true)

		Mode.REMOVE_QUEUED:
			await ctx.battle.remove_queued_states(subject)


## The state this step targets. When it is unset the ability's own state is used
## so a StateStep can stay generic across abilities that share a sequence.
func _state(ctx: ActionSequenceContext) -> Variant:
	if state != null:
		return state

	if ctx != null and ctx.state_sequence and ctx.last_state != null:
		return ctx.last_state

	return null


## The name of the state this step targets, for lookups that match by name.
func _state_name(ctx: ActionSequenceContext) -> String:
	if state != null:
		return state.name

	if ctx != null and ctx.state_sequence and ctx.last_state != null:
		return ctx.last_state.name

	return ""


## The state resource this step adds, or null when it defers to the ability or
## is not an add-state step.
func added_state() -> State:
	if mode != Mode.ADD:
		return null

	return state


## The trap this step places, or null when it defers to the ability or is not a
## trap step.
func placed_trap() -> Trap:
	if mode != Mode.SET_TRAP:
		return null

	return trap


func _to_string() -> String:
	var who := str(actor) if actor != null else "Target"

	match mode:
		Mode.ADD:
			return "Add state '%s' to %s" % [_state_label(), who]

		Mode.REMOVE:
			return "Remove state '%s' from %s" % [_state_label(), who]

		Mode.CLEAR:
			return "Clear every state on %s" % who

		Mode.SET_TRAP:
			return "Set trap on %s" % who

		Mode.AURA_OVERWRITE:
			return "Overwrite %s's aura for %d turns" % [who, turns]

		Mode.SET_TURNS:
			return "Set state '%s' to %d turns on %s" % [_state_label(), turns, who]

		Mode.ADD_TURNS:
			return "Add %d turns to state '%s' on %s" % [turns, _state_label(), who]

		Mode.REMOVE_RANDOM:
			return "Remove a random state from %s" % who

		Mode.REMOVE_QUEUED:
			return "Remove queued states from %s" % who

	return ""


## A readable name for the state, since a bare resource would print its path and
## internal id.
func _state_label() -> String:
	if state == null:
		return "the ability's state"

	if state.resource_name != "":
		return state.resource_name

	return state.name if state.name != "" else state.resource_path.get_file().get_basename()


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode", "actor"]

	match mode:
		Mode.ADD:
			visible.append_array(["state", "turns", "silent", "wait"])

		Mode.REMOVE:
			visible.append("state")

		Mode.CLEAR, Mode.REMOVE_RANDOM, Mode.REMOVE_QUEUED:
			pass

		Mode.SET_TRAP:
			visible.append_array(["trap", "wait"])

		Mode.AURA_OVERWRITE:
			visible.append_array(["color", "turns"])

		Mode.SET_TURNS:
			visible.append_array(["state", "turns"])

		Mode.ADD_TURNS:
			visible.append_array(["state", "turns"])

	StepEditor.only(property, visible)


func _icon() -> String:
	return "CheckBox"
