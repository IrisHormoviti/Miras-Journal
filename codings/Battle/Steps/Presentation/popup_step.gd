@tool
extends BattleStep
class_name PopupStep

## Shows a floating number or word over an actor, such as damage or CRITICAL.

@export var actor: ActorRef
@export var value: StringName = &""
@export var color: ColorRef


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.target

	if subject == null:
		return

	var resolved := color.resolve(ctx) if color != null else Color.WHITE
	ctx.battle.pop_num(subject, str(value), resolved)


func _to_string() -> String:
	var who := str(actor) if actor != null else "Target"
	return "Popup '%s' on %s" % [value, who]


func _validate_property(property: Dictionary) -> void:
	StepEditor.only(property, ["actor", "value", "color"])


func _icon() -> String:
	return "GPUParticles2D"
