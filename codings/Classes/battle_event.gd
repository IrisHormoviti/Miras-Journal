@tool
extends Resource
class_name BattleEvent

## Runs a result when its [member condition] passes. Conditions are regular
## [BattleCondition] resources, so events share the same checks as branches
## instead of having their own flag, turn and stat fields.

@export_category("Condition")
## Condition that decides whether the event runs. Empty always runs.
@export var condition: BattleCondition
## Should be repeated every turn this condition applies.
## Otherwise only runs once.
@export var repeatable := false

@export_category("Result")

enum RES {
	PASSIVE_DIALOG,
	REGULAR_DIALOG,
	FORCE_MOVE,
	VICTORY,
	DEFEAT_OTHERS,
	SEQUENCE,
}

## The battle-menu action a forced move is performed with.
enum MoveAction {
	MAGIC,
	ACT,
	ITEM,
	COMMAND,
}

@export var result: RES = RES.PASSIVE_DIALOG:
	set(value):
		result = value
		notify_property_list_changed()

## Continue to the next turn only after the event is done. Only dialog and
## sequence results can hold the turn.
@export var hold_turn := false

## Dialogue file in [code]database/Text[/code]. The inspector lists every
## dialogue file and any path is reduced to its file name at runtime.
@export var dialog_file := "":
	set(value):
		if dialog_file == value:
			return

		dialog_file = value
		notify_property_list_changed()
## Cue name inside [member dialog_file]. Empty starts at the first cue.
@export_placeholder("First cue") var dialog_cue := ""

## Actor spared by [constant RES.DEFEAT_OTHERS]. Empty uses the current actor.
@export var event_actor: StringName = &""

## Who performs the event's forced move or runs its sequence. Defaults to the
## current actor.
@export var caster: ActorRef = ActorRef.new(ActorRef.Mode.CASTER)
## Who the forced move targets, or what the sequence acts on. Empty keeps the
## current target.
@export var target: ActorRef
## The kind of move the event forces the actor to take.
@export var move_action: MoveAction = MoveAction.MAGIC
## The ability the event forces the actor to use.
@export var move: Ability

@export_category("Sequence")
## The sequence played by [constant RES.SEQUENCE].
@export var sequence: ActionSequence

@export_group("Flag")
## Set this flag after the event runs. Empty leaves flags untouched.
@export var on_run_flag: StringName = &""
## Value written to [member on_run_flag] after the event runs.
@export var on_run_flag_value := true

var ran_this_turn := false
## True while this event is waiting in the battle's background event queue, so
## the same repeatable event cannot be queued twice before it starts.
var queued := false


func check() -> bool:
	if ran_this_turn or queued:
		return false

	if not is_instance_valid(Global.bt):
		return false

	if condition == null:
		return true

	return condition.check(_condition_context())


## Builds a context for the condition from the current battle state.
func _condition_context() -> ActionSequenceContext:
	var ctx := ActionSequenceContext.new()
	ctx.battle = Global.bt
	ctx.runner = Global.bt.action_runner
	ctx.caster = Global.bt.CurrentChar
	ctx.target = Global.bt.CurrentTarget
	return ctx


## Resolves [member event_actor], falling back to the current actor when empty.
func _resolve_event_actor(unsafe := false) -> Actor:
	if event_actor.is_empty():
		return Global.bt.CurrentChar

	return Global.bt.get_actor(event_actor, unsafe)


## The dialogue file name expected by [Textbox] and [Passive]. Accepts either a
## bare name such as [code]story_0[/code] or a path chosen in the inspector.
func _dialog_name() -> String:
	var file_name := dialog_file.get_file()

	if file_name.get_extension() == "dialogue":
		return file_name.get_basename()

	return file_name


## The battle action matching [member move_action].
func _bt_action() -> Actor.BtAction:
	match move_action:
		MoveAction.ACT:
			return Actor.BtAction.ACT

		MoveAction.ITEM:
			return Actor.BtAction.ITEM

		MoveAction.COMMAND:
			return Actor.BtAction.COMMAND

	return Actor.BtAction.MAGIC


func run() -> void:
	queued = false

	if ran_this_turn: return
	else: ran_this_turn = true

	if !Global.bt: return
	print("Running event type ", result)

	if hold_turn and not _can_hold_turn():
		OS.alert("Battle event error: This action cannot hold the turn")
		return

	if hold_turn:
		Battle.push_modal_dialogue()

	# The caller decides whether this holds the turn: [method
	# BattleSequence.call_events] awaits holding events directly and puts the
	# rest through the battle's background queue, which still awaits each one so
	# they never overlap.
	await _run_result()

	if hold_turn:
		Battle.pop_modal_dialogue()

	if not on_run_flag.is_empty():
		Event.add_flag(on_run_flag, 1 if on_run_flag_value else 0)


## Only dialogue and sequences have something to wait for. Forced moves, a
## victory trigger and defeats resolve immediately.
func _can_hold_turn() -> bool:
	return result in [RES.PASSIVE_DIALOG, RES.REGULAR_DIALOG, RES.SEQUENCE]


func _run_result() -> void:
	match result:
		RES.PASSIVE_DIALOG:
			await Passive.open(_dialog_name(), dialog_cue)

		RES.REGULAR_DIALOG:
			await Textbox.open(_dialog_name(), dialog_cue)

		RES.FORCE_MOVE:
			_force_move()

		RES.VICTORY:
			print("Event means win")
			await Global.bt.victory()

		RES.DEFEAT_OTHERS:
			await _defeat_others()

		RES.SEQUENCE:
			await run_sequence()


func _force_move() -> void:
	var ctx := _condition_context()
	var actor_data := caster.resolve(ctx) if caster != null else Global.bt.CurrentChar

	if actor_data == null:
		push_warning("Battle event FORCE_MOVE could not resolve an actor")
	elif actor_data.death_sequence_queued or actor_data.has_state("Knocked Out"):
		print("Skipping forced move; ", actor_data.codename, " is out of the fight")
	else:
		actor_data.next_action = _bt_action()
		actor_data.next_move = move
		print("Forcing ", move.name if move != null else "nothing", " on ", actor_data.codename)

		if target != null:
			var resolved_target := target.resolve(ctx)

			if resolved_target != null:
				actor_data.next_target = resolved_target


func _defeat_others() -> void:
	var actor_data := _resolve_event_actor(true)
	var spared := actor_data.codename if actor_data != null else event_actor
	print("Defeating everyone but ", spared)

	if actor_data != null and actor_data.is_enemy:
		for i in Global.bt.Troop:
			if actor_data != i:
				await Global.bt.death(i)


## Runs the event's sequence with the same caster and target as a forced move.
## Sequences hold the turn themselves when they need to, so the event never adds
## a second lock.
func run_sequence() -> void:
	if sequence == null:
		return

	var ctx := _condition_context()
	var seq_caster: Actor = Global.bt.CurrentChar

	if caster != null:
		var resolved_caster := caster.resolve(ctx)

		if resolved_caster != null:
			seq_caster = resolved_caster

	var seq_target: Actor = Global.bt.CurrentTarget

	if target != null:
		var resolved_target := target.resolve(ctx)

		if resolved_target != null:
			seq_target = resolved_target

	await Global.bt.run_battle_sequence(sequence, seq_caster, seq_target, false)


## Only the properties that matter for the current result are shown in the
## inspector, so events never expose dialog fields for a forced move (or the
## other way around).
func _validate_property(property: Dictionary) -> void:
	# Friendlier enum labels than the raw constant names.
	if property.name == &"result":
		property.hint_string = "Passive dialogue,Regular dialogue,Force move,Victory,Defeat others,Sequence"
	elif property.name == &"dialog_file":
		StepEditor.dialogue_files(property)
	elif property.name == &"dialog_cue":
		StepEditor.dialogue_cues(property, dialog_file)

	var visible: Array[String] = ["condition", "repeatable", "result"]

	match result:
		RES.PASSIVE_DIALOG, RES.REGULAR_DIALOG:
			visible.append_array(["dialog_file", "dialog_cue", "hold_turn"])

		RES.FORCE_MOVE:
			visible.append_array(["caster", "move_action", "move", "target"])

		RES.VICTORY:
			pass

		RES.DEFEAT_OTHERS:
			visible.append("event_actor")

		RES.SEQUENCE:
			visible.append_array(["sequence", "caster", "target", "hold_turn"])

	visible.append_array(["on_run_flag", "on_run_flag_value"])
	StepEditor.only(property, visible)
