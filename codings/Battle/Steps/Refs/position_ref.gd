@tool
extends Resource
class_name PositionRef

enum Mode {
	HOME,
	CURRENT,
	ABSOLUTE,
	ABSOLUTE_X,
	ABSOLUTE_Y,
	ACTOR,
	TARGET,
	SIDE_POSITION,
	ACTOR_POSITION,
	TARGET_POSITION,
	RANDOM_OFFSET,
}

@export var mode: Mode = Mode.CURRENT:
	set(value):
		mode = value
		refresh_name()
		notify_property_list_changed()
@export var actor: ActorRef
@export var position := Vector2.ZERO:
	set(value):
		position = value
		refresh_name()
## Absolute X in world space, used by ABSOLUTE_X.
@export var x := 0.0:
	set(value):
		x = value
		refresh_name()
## Absolute Y in world space, used by ABSOLUTE_Y.
@export var y := 0.0:
	set(value):
		y = value
		refresh_name()
@export var offset := Vector2.ZERO:
	set(value):
		offset = value
		refresh_name()
## Mirrors the horizontal component for the acting side. Use this for positions
## that legacy sequences wrote as Bt.offsetize(...).
@export var side_aware := false:
	set(value):
		side_aware = value
		refresh_name()
@export var random_min := Vector2(-10, -10)
@export var random_max := Vector2(10, 10)


func _init(p_mode: Mode = Mode.CURRENT) -> void:
	mode = p_mode
	refresh_name()


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
			return Vector2(_side_x(ctx, position.x), position.y)

		Mode.ABSOLUTE_X:
			return Vector2(_side_x(ctx, x), subject.node.position.y)

		Mode.ABSOLUTE_Y:
			return Vector2(subject.node.position.x, y)

		Mode.ACTOR:
			return _actor_position(ctx, ctx.caster) + _offset(ctx)

		Mode.TARGET:
			return _actor_position(ctx, ctx.target) + _offset(ctx)

		Mode.SIDE_POSITION:
			return subject.node.position + Vector2(ctx.battle.offsetize(offset.x, subject), offset.y)

		Mode.ACTOR_POSITION:
			return _actor_position(ctx, actor.resolve(ctx) if actor != null else ctx.caster) + _offset(ctx)
		Mode.TARGET_POSITION:
			return _actor_position(ctx, ctx.target) + _offset(ctx)

		Mode.RANDOM_OFFSET:
			var random_offset := Vector2(
				randf_range(random_min.x, random_max.x),
				randf_range(random_min.y, random_max.y)
			)
			return subject.node.position + _offset(ctx) + random_offset

	return subject.node.position


func _side_x(ctx: ActionSequenceContext, value: float) -> float:
	if not side_aware:
		return value

	return ctx.battle.offsetize(value, ctx.caster)


func _offset(ctx: ActionSequenceContext) -> Vector2:
	return Vector2(_side_x(ctx, offset.x), offset.y)


func _actor_position(ctx: ActionSequenceContext, target: Actor) -> Vector2:
	if target == null or target.node == null:
		return Vector2.ZERO

	return target.node.position


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]

	match mode:
		Mode.HOME, Mode.CURRENT:
			pass

		Mode.ABSOLUTE:
			visible.append_array(["position", "side_aware"])

		Mode.ABSOLUTE_X:
			visible.append_array(["x", "side_aware"])

		Mode.ABSOLUTE_Y:
			visible.append("y")

		Mode.ACTOR, Mode.TARGET, Mode.TARGET_POSITION:
			visible.append_array(["offset", "side_aware"])

		Mode.SIDE_POSITION:
			visible.append("offset")

		Mode.ACTOR_POSITION:
			visible.append_array(["actor", "offset", "side_aware"])

		Mode.RANDOM_OFFSET:
			visible.append_array(["offset", "random_min", "random_max", "side_aware"])

	StepEditor.only(property, visible)


func refresh_name() -> void:
	resource_name = str(self)


func _to_string() -> String:
	var suffix := " (side)" if side_aware else ""

	match mode:
		Mode.ABSOLUTE:
			return str(position) + suffix

		Mode.ABSOLUTE_X:
			return "x %s%s" % [str(x), suffix]

		Mode.ABSOLUTE_Y:
			return "y %s" % str(y)

	return str(Mode.find_key(mode)).capitalize()
