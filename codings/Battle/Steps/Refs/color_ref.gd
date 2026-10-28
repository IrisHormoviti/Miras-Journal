@tool
extends Resource
class_name ColorRef

enum Mode {
	FIXED,
	ACTOR_COLOR,
	SECONDARY_COLOR,
	WHEEL_COLOR,
	RANDOM,
	ELEMENT,
}

@export var mode: Mode = Mode.WHEEL_COLOR:
	set(value):
		mode = value
		notify_property_list_changed()
		resource_name = str(self)
@export var actor: ActorRef
@export var color := Color.WHITE
@export var element: StringName = &""
@export var random_min := Color(0.2, 0.2, 0.2, 1.0)
@export var random_max := Color(0.8, 0.8, 0.8, 1.0)


func _init() -> void:
	resource_name = str(self)


func resolve(ctx: ActionSequenceContext) -> Color:
	var subject := ctx.caster

	if actor != null:
		subject = actor.resolve(ctx)

	match mode:
		Mode.FIXED:
			return color

		Mode.ACTOR_COLOR:
			return subject.main_color if subject != null else color
		Mode.SECONDARY_COLOR:
			return subject.secondary_color if subject != null else color
		Mode.WHEEL_COLOR:
			return ctx.ability.wheel_color if ctx.ability != null else color
		Mode.RANDOM:
			return Color(
				randf_range(random_min.r, random_max.r),
				randf_range(random_min.g, random_max.g),
				randf_range(random_min.b, random_max.b),
				randf_range(random_min.a, random_max.a)
			)
		Mode.ELEMENT:
			return Colorizer.ElementColor.get(element, color)

	return color


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]

	match mode:
		Mode.FIXED:
			visible.append("color")

		Mode.ACTOR_COLOR, Mode.SECONDARY_COLOR:
			visible.append("actor")

		Mode.WHEEL_COLOR:
			pass

		Mode.RANDOM:
			visible.append_array(["random_min", "random_max"])

		Mode.ELEMENT:
			visible.append_array(["element", "color"])

	StepEditor.only(property, visible)


func _to_string() -> String:
	match mode:
		Mode.FIXED:
			return color.to_html(false)

		Mode.ELEMENT:
			return "Element color" if element.is_empty() else "%s color" % String(element).capitalize()

	return str(Mode.find_key(mode)).capitalize()
