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
}

@export var mode: Mode = Mode.ADD:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var state_name: StringName = &""
@export var turns := -1
@export var inflicter: ActorRef
@export var silent := false
@export var use_ability_state := false:
	set(value):
		use_ability_state = value
		notify_property_list_changed()
@export var trap: Trap
@export var use_ability_trap := false:
	set(value):
		use_ability_trap = value
		notify_property_list_changed()
@export var color: ColorRef


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.target
	if subject == null:
		return

	match mode:
		Mode.ADD:
			var name := _state_name(ctx)
			ctx.last_state = await subject.add_state(name, turns, _inflicter(ctx), not silent)
		Mode.REMOVE:
			subject.remove_state(_state_name(ctx))
		Mode.CLEAR:
			ctx.battle.clear_states(subject)
		Mode.SET_TRAP:
			var place := trap
			if use_ability_trap and ctx.ability != null:
				place = ctx.ability.SetsTrap
			ctx.last_state = await ctx.battle.apply_trap(place, subject, _inflicter(ctx))
		Mode.AURA_OVERWRITE:
			var overwrite := color.resolve(ctx) if color != null else subject.MainColor
			await ctx.battle.aura_overwrite(subject, overwrite, turns)
		Mode.SET_TURNS:
			var current := subject.get_state(str(_state_name(ctx)))
			if current != null:
				current.turns = turns
		Mode.REMOVE_RANDOM:
			if not subject.States.is_empty():
				var random_state: State = subject.States.pick_random()
				ctx.last_state = random_state
				subject.remove_state(random_state)
		Mode.REMOVE_QUEUED:
			ctx.battle.remove_queued_states(subject)


func _state_name(ctx: ActionSequenceContext) -> String:
	if use_ability_state and ctx.ability != null:
		return ctx.ability.InflictsState
	return str(state_name)


func _inflicter(ctx: ActionSequenceContext) -> Actor:
	if inflicter != null:
		return inflicter.resolve(ctx)
	return ctx.caster


func _to_string() -> String:
	var who := str(actor) if actor != null else "Target"

	match mode:
		Mode.ADD:
			if use_ability_state:
				return "Add the ability's state to %s" % who

			return "Add state '%s' to %s" % [state_name, who]

		Mode.REMOVE:
			if use_ability_state:
				return "Remove the ability's state from %s" % who

			return "Remove state '%s' from %s" % [state_name, who]

		Mode.CLEAR:
			return "Clear every state on %s" % who

		Mode.SET_TRAP:
			if use_ability_trap:
				return "Set the ability's trap on %s" % who

			return "Set trap on %s" % who

		Mode.AURA_OVERWRITE:
			return "Overwrite %s's aura for %d turns" % [who, turns]

		Mode.SET_TURNS:
			if use_ability_state:
				return "Set the ability's state to %d turns on %s" % [turns, who]

			return "Set state '%s' to %d turns on %s" % [state_name, turns, who]

		Mode.REMOVE_RANDOM:
			return "Remove a random state from %s" % who

		Mode.REMOVE_QUEUED:
			return "Remove queued states from %s" % who

	return ""


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode", "actor"]
	match mode:
		Mode.ADD:
			visible.append_array(["turns", "inflicter", "silent", "use_ability_state"])
			if not use_ability_state:
				visible.append("state_name")
		Mode.REMOVE:
			visible.append("use_ability_state")
			if not use_ability_state:
				visible.append("state_name")
		Mode.CLEAR, Mode.REMOVE_RANDOM, Mode.REMOVE_QUEUED:
			pass
		Mode.SET_TRAP:
			visible.append_array(["inflicter", "use_ability_trap"])
			if not use_ability_trap:
				visible.append("trap")
		Mode.AURA_OVERWRITE:
			visible.append_array(["color", "turns"])
		Mode.SET_TURNS:
			visible.append_array(["turns", "use_ability_state"])
			if not use_ability_state:
				visible.append("state_name")
	StepEditor.only(property, visible)


func _icon() -> String:
	return "CheckBox"
