@tool
extends BattleStep
class_name CameraStep

## What the camera should point at when move is enabled.
enum MoveTarget {
	FOCUS,
	POSITION,
	RESET,
}

@export_group("Zoom")
## Zoom the camera in or out
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var zoom_enabled := false
## Zoom multiplier, where higher is closer.
@export var amount := 5.0

@export_group("Move")
## Move the camera
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var move_enabled := false
## What the camera points at while moving.
@export var move_target: MoveTarget = MoveTarget.FOCUS:
	set(value):
		move_target = value
		notify_property_list_changed()
@export var actor := ActorRef.new(ActorRef.Mode.TARGET)
@export var position: PositionRef
@export var offset := Vector2(30, 0)

## Shared camera timing.
@export_category("Timing")
@export var duration := 0.5
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT
## When false, the next step starts while the camera is still moving.
@export var wait := false


func run(ctx: ActionSequenceContext) -> void:
	if zoom_enabled:
		if wait:
			await ctx.battle.zoom(amount, duration, easing)
		else:
			ctx.battle.zoom(amount, duration, easing)

	if move_enabled:
		await _move(ctx)


func _move(ctx: ActionSequenceContext) -> void:
	match move_target:
		MoveTarget.FOCUS:
			var subject := actor.resolve(ctx) if actor != null else ctx.target

			if subject == null:
				return

			if wait:
				await ctx.battle.focus_cam(subject, duration, offset)
			else:
				ctx.battle.focus_cam(subject, duration, offset)

		MoveTarget.POSITION:
			var target := position.resolve(ctx) if position != null else Vector2.ZERO

			if wait:
				await ctx.battle.move_cam(target, duration)
			else:
				ctx.battle.move_cam(target, duration)

		MoveTarget.RESET:
			if wait:
				await ctx.battle.move_cam(Vector2.ZERO, duration)
			else:
				ctx.battle.move_cam(Vector2.ZERO, duration)


func _to_string() -> String:
	var parts: Array[String] = []

	if zoom_enabled:
		parts.append("zoom to %sx" % str(amount))

	if move_enabled:
		match move_target:
			MoveTarget.FOCUS:
				var who := str(actor) if actor != null else "Target"
				parts.append("focus on %s" % who)

			MoveTarget.POSITION:
				parts.append("move to %s" % position)

			MoveTarget.RESET:
				parts.append("reset")

	if parts.is_empty():
		return "Camera unchanged"

	return "Camera " + ", ".join(parts)


func _validate_property(property: Dictionary) -> void:
	# The enable groups hide the inactive sections already, so only the move
	# target's own fields need filtering here.
	if not move_enabled:
		return

	var hidden: Array[String] = []

	match move_target:
		MoveTarget.FOCUS:
			hidden.append("position")

		MoveTarget.POSITION:
			hidden.append_array(["actor", "offset"])

		MoveTarget.RESET:
			hidden.append_array(["actor", "position", "offset"])

	StepEditor.hide(property, hidden)


func _icon() -> String:
	return "Camera"
