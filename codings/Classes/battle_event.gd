extends Resource
class_name BattleEvent

@export_group("Condition")
## Should be repeated every turn this condition applies.
## Otherwise only runs once.
@export var repeatable := false
##Check this flag
@export var flag: StringName = &""
@export var flag_should_be: bool = false
##If all other conditions are met, the event will play on this turn or after it, -1 to disable
@export var after_turn: int = -1
##The event will play if the actor's HP is lower than [member low_hp]. Leave empty to skip
@export var actor: StringName = &""
## Activate when HP is below this, -1 to disable
@export var low_hp: int = -1
## Activate when HP is below this, -1 to disable
@export var low_ap: int = -1
@export_group("Result")

enum RES {PASSIVE_DIALOG, CALL_FUNCTION, REGULAR_DIALOG, FORCE_MOVE, VICTORY, DEFEAT_OTHERS}
@export var result: RES = RES.PASSIVE_DIALOG

##Used as text file for dialog, function name for call function, move type for force move
@export var parameter1: String = ""
##Used as node name for dialog
@export var parameter2: String = ""
@export var resource: Resource = null
##Continue to the next turn only after the event is done
@export var hold_turn := false
##set [member flag] to the oposite of [member flag_should_be] after running
@export var add_flag: bool = true
var ran_this_turn := false


func check() -> bool:
	var actore := Global.bt.get_actor(actor)

	if ran_this_turn: return false
	if not is_instance_valid(Global.bt): return false
	if not flag.is_empty() and Event.check_flag(flag) != flag_should_be:
		return false

	if after_turn != -1:
		if Global.bt.Turn < after_turn: return false

	if low_hp != -1 and low_hp >= 0:
		if actor == &"" or actore == null:
			push_warning("The event refrences " + actor + " who is not present")
			return false

		if actore.Health >= low_hp: return false

	if low_ap != -1 and low_ap >= 0:
		if actor == &"" or actore == null:
			push_warning("The event refrences " + actor + " who is not present")
			return false

		if actore.Aura > low_ap: return false

	if low_hp == 0:
		if actore != null and not actore.has_state("KnockedOut"):
			return false

	return true


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

			RES.CALL_FUNCTION:
				print("Call seq: ", parameter1)
				Global.bt.get_node("Act").call(parameter1)

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

				var actor_data := Global.bt.get_actor(actor)
				actor_data.NextAction = action
				actor_data.NextMove = resource
				print("Forcing ", resource.name, " on ", actor)
				if not parameter2.is_empty():
					actor_data.NextTarget = Global.bt.get_actor(parameter2)

			RES.VICTORY:
				print("Event means win")
				Global.bt.victory()

			RES.DEFEAT_OTHERS:
				print("Defeating everyone but ", actor)
				var actor_data := Global.bt.get_actor(actor, true)

				if actor_data != null and actor_data.IsEnemy:
					for i in Global.bt.Troop:
						if actor_data != i:
							Global.bt.death(i)

	if add_flag and flag != "": Event.add_flag(flag, !flag_should_be)


func run_with_await() -> void:
	match result:
		0: await Passive.open(parameter1, parameter2)
		1: await Global.bt.get_node("Act").call(parameter1)
		2: await Textbox.open(parameter1, parameter2)
		_: OS.alert("Battle event error: This action cannot hold the turn")
