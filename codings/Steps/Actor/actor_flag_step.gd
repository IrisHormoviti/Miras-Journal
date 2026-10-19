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
}

@export var mode: Mode = Mode.CANT_DIE:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var enabled := true
@export var ability_index := 0


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.target

	if subject == null:
		return

	match mode:
		Mode.CANT_DIE:
			subject.CantDie = enabled

		Mode.IGNORE_STATES:
			subject.IgnoreStates = enabled

		Mode.DONT_IDLE:
			subject.DontIdle = enabled

		Mode.CLUTCH_DAMAGE:
			subject.ClutchDmg = enabled

		Mode.ABILITY_DISABLED:
			if ability_index >= 0 and ability_index < subject.Abilities.size():
				subject.Abilities[ability_index].disabled = not enabled

		Mode.CONTROLLABLE:
			subject.Controllable = enabled


func _to_string() -> String:
	var who := str(actor) if actor != null else "Target"
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

	return ""


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode", "actor", "enabled"]

	if mode == Mode.ABILITY_DISABLED:
		visible.append("ability_index")

	StepEditor.only(property, visible)


func _icon() -> String:
	return "ProjectList"
