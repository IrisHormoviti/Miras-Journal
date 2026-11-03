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
@export var result: RES = RES.PASSIVE_DIALOG

## Used as text file for dialog or move type for force move
@export var parameter1: String = ""
## Used as node name for dialog
@export var parameter2: String = ""
@export var resource: Resource = null
##Continue to the next turn only after the event is done
@export var hold_turn := false
## Actor affected by [constant RES.FORCE_MOVE] or spared by
## [constant RES.DEFEAT_OTHERS]. Empty uses the current actor.
@export var event_actor: StringName = &""
## Set this flag after the event runs. Empty leaves flags untouched.
@export var on_run_flag: StringName = &""
## Value written to [member on_run_flag] after the event runs.
@export var on_run_flag_value := true

@export_group("Sequence")
## The sequence played by [constant RES.SEQUENCE].
@export var sequence: ActionSequence
## Codename of the actor that runs the sequence. Empty uses the current actor.
@export var sequence_caster: StringName = &""
## Codename of the actor the sequence targets. Empty uses the current target.
@export var sequence_target: StringName = &""
var ran_this_turn := false


func check() -> bool:
	if ran_this_turn:
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


func run() -> void:
	if ran_this_turn: return
	else: ran_this_turn = true

	if !Global.bt: return
	print("Running event type ", result)
	if hold_turn: await run_with_await()
	else:
		match result:
			RES.PASSIVE_DIALOG:
				Passive.open(parameter1, parameter2)

			RES.REGULAR_DIALOG:
				Textbox.open(parameter1, parameter2)

			RES.FORCE_MOVE:
				var action: Actor.BtAction = Actor.BtAction.MAGIC

				match parameter1:
					"Attack", "Act":
						action = Actor.BtAction.ACT

					"Item":
						action = Actor.BtAction.ITEM

					"Command":
						action = Actor.BtAction.COMMAND

				var actor_data := _resolve_event_actor()

				if actor_data == null:
					push_warning("Battle event FORCE_MOVE could not resolve an actor")
				else:
					actor_data.next_action = action
					actor_data.next_move = resource
					print("Forcing ", resource.name, " on ", actor_data.codename)

					if not parameter2.is_empty():
						actor_data.next_target = Global.bt.get_actor(parameter2)

			RES.VICTORY:
				print("Event means win")
				Global.bt.victory()

			RES.DEFEAT_OTHERS:
				var actor_data := _resolve_event_actor(true)
				var spared := actor_data.codename if actor_data != null else event_actor
				print("Defeating everyone but ", spared)

				if actor_data != null and actor_data.is_enemy:
					for i in Global.bt.Troop:
						if actor_data != i:
							Global.bt.death(i)

			RES.SEQUENCE:
				run_sequence()

	if not on_run_flag.is_empty():
		Event.add_flag(on_run_flag, 1 if on_run_flag_value else 0)


func run_with_await() -> void:
	match result:
		RES.PASSIVE_DIALOG: await Passive.open(parameter1, parameter2)
		RES.REGULAR_DIALOG: await Textbox.open(parameter1, parameter2)
		RES.SEQUENCE: await run_sequence()
		_: OS.alert("Battle event error: This action cannot hold the turn")


## Runs the event's sequence with the event's caster and target. Sequences hold
## the turn themselves when they need to, so the event never adds a second lock.
func run_sequence() -> void:
	if sequence == null:
		return

	var seq_caster: Actor = Global.bt.CurrentChar

	if not sequence_caster.is_empty():
		seq_caster = Global.bt.get_actor(sequence_caster, true)

	var seq_target: Actor = Global.bt.CurrentTarget

	if not sequence_target.is_empty():
		seq_target = Global.bt.get_actor(sequence_target, true)

	await Global.bt.run_battle_sequence(sequence, seq_caster, seq_target, false)
