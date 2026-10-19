@tool
extends BattleStep
class_name MoveStep

enum Mode {
	WALK,
	JUMP,
	RETURN,
}

@export var mode: Mode = Mode.WALK:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var destination: PositionRef
@export var offset := Vector2.ZERO
@export var duration := 0.5
@export var height := 0.5
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT
@export var wait := true


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.caster

	if subject == null or subject.node == null:
		return

	match mode:
		Mode.WALK:
			var walk_target := destination.resolve(ctx, subject) + offset if destination != null else subject.node.position + offset

			if wait:
				await ctx.battle.move(subject, walk_target, duration, easing)
			else:
				ctx.battle.move(subject, walk_target, duration, easing)

		Mode.JUMP:
			var jump_target := destination.resolve(ctx, subject) + offset if destination != null else subject.node.position + offset

			if wait:
				await ctx.battle.jump_to(subject, jump_target, duration, height)
			else:
				ctx.battle.jump_to(subject, jump_target, duration, height)

		Mode.RETURN:
			if wait:
				await ctx.battle.return_cur(subject)
			else:
				ctx.battle.return_cur(subject)


func _to_string() -> String:
	var who := str(actor) if actor != null else "Caster"

	match mode:
		Mode.WALK:
			return "Walk %s" % who

		Mode.JUMP:
			return "Jump %s" % who

		Mode.RETURN:
			return "Return %s" % who

	return ""


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode", "actor"]

	match mode:
		Mode.WALK:
			visible.append_array(["destination", "offset", "duration", "easing", "wait"])

		Mode.JUMP:
			visible.append_array(["destination", "offset", "duration", "height", "easing", "wait"])

		Mode.RETURN:
			visible.append("wait")

	StepEditor.only(property, visible)


func _icon() -> String:
	return "ToolMove"
