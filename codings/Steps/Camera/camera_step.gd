@tool
extends BattleStep
class_name CameraStep

enum Mode {
	FOCUS,
	ZOOM,
	MOVE,
	RESET,
	SHAKE,
}

@export var mode: Mode = Mode.FOCUS:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var position: PositionRef
@export var offset := Vector2(30, 0)
@export var amount := 5.0
@export var duration := 0.5
@export var repeat := 7
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT
## When false, the next step starts while the camera is still moving.
@export var wait := false


func run(ctx: ActionSequenceContext) -> void:
	match mode:
		Mode.FOCUS:
			var subject := actor.resolve(ctx) if actor != null else ctx.target

			if subject != null:
				if wait:
					await ctx.battle.focus_cam(subject, duration, offset)
				else:
					ctx.battle.focus_cam(subject, duration, offset)

		Mode.ZOOM:
			if wait:
				await ctx.battle.zoom(amount, duration, easing)
			else:
				ctx.battle.zoom(amount, duration, easing)

		Mode.MOVE:
			var target := position.resolve(ctx) if position != null else Vector2.ZERO

			if wait:
				await ctx.battle.move_cam(target, duration)
			else:
				ctx.battle.move_cam(target, duration)

		Mode.RESET:
			if wait:
				await ctx.battle.zoom(5, duration, easing)
				await ctx.battle.move_cam(Vector2.ZERO, duration)
			else:
				ctx.battle.zoom(5, duration, easing)
				ctx.battle.move_cam(Vector2.ZERO, duration)

		Mode.SHAKE:
			if wait:
				await ctx.battle.screen_shake(amount, repeat, duration)
			else:
				ctx.battle.screen_shake(amount, repeat, duration)


func _to_string() -> String:
	var who := str(actor) if actor != null else "Target"

	match mode:
		Mode.FOCUS:
			return "Focus on %s" % who

		Mode.ZOOM:
			return "Zoom to %sx" % str(amount)

		Mode.MOVE:
			return "Move the camera"

		Mode.RESET:
			return "Reset the camera"

		Mode.SHAKE:
			return "Shake the camera"

	return ""


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]

	match mode:
		Mode.FOCUS:
			visible.append_array(["actor", "offset", "duration", "wait"])

		Mode.ZOOM:
			visible.append_array(["amount", "duration", "easing", "wait"])

		Mode.MOVE:
			visible.append_array(["position", "duration", "wait"])

		Mode.RESET:
			visible.append_array(["duration", "easing", "wait"])

		Mode.SHAKE:
			visible.append_array(["amount", "repeat", "duration", "wait"])

	StepEditor.only(property, visible)


func _icon() -> String:
	return "Camera"
