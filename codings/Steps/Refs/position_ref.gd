@tool
extends Resource
class_name PositionRef

enum Mode {
	HOME,
	CURRENT,
	ABSOLUTE,
	ABSOLUTE_X,
	ABSOLUTE_Y,
	RELATIVE_TO_ACTOR,
	RELATIVE_TO_TARGET,
	SIDE_POSITION,
	ACTOR_POSITION,
	TARGET_POSITION,
	RANDOM_OFFSET,
}

@export var mode: Mode = Mode.CURRENT:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var position := Vector2.ZERO
@export var offset := Vector2.ZERO
@export var random_min := Vector2(-10, -10)
@export var random_max := Vector2(10, 10)


func resolve(ctx: ActionSequenceContext, default_actor: Actor = null) -> Vector2:
	var subject := default_actor
	if subject == null:
		subject = ctx.target if ctx.target != null else ctx.caster
	if subject == null or subject.node == null:
		return position

	match mode:
		Mode.HOME:
			return ctx.home_position
		Mode.CURRENT:
			return subject.node.position
		Mode.ABSOLUTE:
			return position
		Mode.ABSOLUTE_X:
			return Vector2(position.x, subject.node.position.y)
		Mode.ABSOLUTE_Y:
			return Vector2(subject.node.position.x, position.y)
		Mode.RELATIVE_TO_ACTOR:
			return _actor_position(ctx, ctx.caster) + offset
		Mode.RELATIVE_TO_TARGET:
			return _actor_position(ctx, ctx.target) + offset
		Mode.SIDE_POSITION:
			return subject.node.position + Vector2(ctx.battle.offsetize(offset.x, subject), offset.y)
		Mode.ACTOR_POSITION:
			return _actor_position(ctx, actor.resolve(ctx) if actor != null else ctx.caster) + offset
		Mode.TARGET_POSITION:
			return _actor_position(ctx, ctx.target) + offset
		Mode.RANDOM_OFFSET:
			var random_offset := Vector2(
				randf_range(random_min.x, random_max.x),
				randf_range(random_min.y, random_max.y)
			)
			return subject.node.position + offset + random_offset

	return subject.node.position


func _actor_position(ctx: ActionSequenceContext, target: Actor) -> Vector2:
	if target == null or target.node == null:
		return Vector2.ZERO
	return target.node.position


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]
	match mode:
		Mode.HOME, Mode.CURRENT:
			pass
		Mode.ABSOLUTE, Mode.ABSOLUTE_X, Mode.ABSOLUTE_Y:
			visible.append("position")
		Mode.RELATIVE_TO_ACTOR, Mode.RELATIVE_TO_TARGET, Mode.SIDE_POSITION, Mode.TARGET_POSITION:
			visible.append("offset")
		Mode.ACTOR_POSITION:
			visible.append_array(["actor", "offset"])
		Mode.RANDOM_OFFSET:
			visible.append_array(["offset", "random_min", "random_max"])
	StepEditor.only(property, visible)
