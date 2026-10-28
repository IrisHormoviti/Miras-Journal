@tool
extends BattleStep
class_name ActorFlagStep

enum Mode {
	CANT_DIE,
	IGNORE_STATES,
	DONT_IDLE,
	CLUTCH_DAMAGE,
	ABILITY_DISABLED,
	CONTROLLABLE,
	NEXT_ACTION,
}

@export var mode: Mode = Mode.CANT_DIE:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var enabled := true
@export var ability_index := 0
## The turn the actor takes on their next move.
@export var next_action: Actor.BtAction = Actor.BtAction.ACT
## The ability the actor will use, left empty to keep their own choice.
@export var next_move: Ability
## Who the actor will aim at, left empty to keep their own choice.
@export var next_target: ActorRef


func run(ctx: ActionSequenceContext) -> void:
	var subject := _subject(ctx)

	if subject == null:
		return

	match mode:
		Mode.CANT_DIE:
			subject.cant_die = enabled

		Mode.IGNORE_STATES:
			subject.ignore_states = enabled

		Mode.DONT_IDLE:
			subject.dont_idle = enabled

		Mode.CLUTCH_DAMAGE:
			subject.clutch_dmg = enabled

		Mode.ABILITY_DISABLED:
			if ability_index >= 0 and ability_index < subject.abilities.size():
				subject.abilities[ability_index].disabled = not enabled

		Mode.CONTROLLABLE:
			subject.controllable = enabled

		Mode.NEXT_ACTION:
			subject.next_action = next_action

			if next_move != null:
				subject.next_move = next_move

			if next_target != null:
				subject.next_target = next_target.resolve(ctx)


## The actor this step acts on. Scripting a turn defaults to the caster, since a
## next move usually describes the actor running the sequence.
func _subject(ctx: ActionSequenceContext) -> Actor:
	if actor != null:
		return actor.resolve(ctx)

	if mode == Mode.NEXT_ACTION:
		return ctx.caster

	return ctx.target


func _to_string() -> String:
	var who := _who()
	var state := "on" if enabled else "off"

	match mode:
		Mode.CANT_DIE:
			return "Can't die for %s: %s" % [who, state]

		Mode.IGNORE_STATES:
			return "Ignore states for %s: %s" % [who, state]

		Mode.DONT_IDLE:
			return "Don't idle %s: %s" % [who, state]

		Mode.CLUTCH_DAMAGE:
			return "Clutch damage for %s: %s" % [who, state]

		Mode.ABILITY_DISABLED:
			return "Ability %d on %s: %s" % [ability_index, who, "enabled" if enabled else "disabled"]

		Mode.CONTROLLABLE:
			return "Controllable %s: %s" % [who, state]

		Mode.NEXT_ACTION:
			return "Next move for %s: %s" % [who, Actor.BtAction.find_key(next_action)]

	return ""


## The label for this step's subject, matching the caster default of a next move.
func _who() -> String:
	if actor != null:
		return str(actor)

	return "Caster" if mode == Mode.NEXT_ACTION else "Target"


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode", "actor"]

	if mode == Mode.ABILITY_DISABLED:
		visible.append_array(["enabled", "ability_index"])
	elif mode == Mode.NEXT_ACTION:
		visible.append_array(["next_action", "next_move", "next_target"])
	else:
		visible.append("enabled")

	StepEditor.only(property, visible)


func _icon() -> String:
	return "ProjectList"
