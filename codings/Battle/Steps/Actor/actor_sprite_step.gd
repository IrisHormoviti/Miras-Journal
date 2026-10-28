@tool
extends BattleStep
class_name ActorSpriteStep

enum Mode {
	ANIMATION,
	VISIBLE,
	# Value 2 used to be POSITION. Instant actor movement now lives on
	# MoveStep.Mode.TELEPORT, so keep the remaining serialized values stable.
	FRAME = 3,
	FLIP,
	COLOR,
	SHADER_PARAM,
	GLOW,
	OUTLINE,
	SHAKE,
	NODE_VISIBLE,
	Z_INDEX,
	PLAY_BACKWARDS,
}

## Standard battle animation names, offered as a dropdown in the inspector.
const ANIMATION_PRESETS: Array[StringName] = [
	&"",
	&"Idle",
	&"IdleRight",
	&"Entrance",
	&"Hit",
	&"Attack1",
	&"Attack2",
	&"Attack3",
	&"Ability",
	&"AbilityLoop",
	&"Cast",
	&"Item",
	&"Bag",
	&"BagLoop",
	&"Command",
	&"Victory",
	&"VictoryLoop",
	&"KnockOut",
]

@export var mode: Mode = Mode.ANIMATION:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef = ActorRef.new()
@export var animation: StringName = &""
@export_storage var wait := false
@export var visible := true
@export var frame := 0
@export var pause := false
@export var flip := false
@export var color: ColorRef
@export var node_path: NodePath = ^""
@export var shader_param: StringName = &""
@export var shader_value := 0.0
@export var shader_color := Color.WHITE
@export var shader_value_is_color := false:
	set(value):
		shader_value_is_color = value
		notify_property_list_changed()
@export var use_material_override := false
@export var glow_amount := 1.0
@export var glow_time := 1.0
@export var outline_remove := false
@export var outline_time := 0.5
@export var shake_amount := 2.0
@export var shake_repeat := 5
@export var shake_time := 0.03
@export var z_index := 1


func run(ctx: ActionSequenceContext) -> void:
	var subject := _actor(ctx)

	if subject == null or subject.node == null:
		return

	match mode:
		Mode.ANIMATION:
			if wait:
				await ctx.battle.anim(str(animation), subject)
			else:
				ctx.battle.anim(str(animation), subject)

		Mode.VISIBLE:
			subject.node.visible = visible

		Mode.FRAME:
			if animation != &"":
				subject.node.animation = animation

			subject.node.frame = frame

			if pause:
				subject.node.pause()

		Mode.FLIP:
			subject.flip_h = flip
			subject.node.flip_h = flip

		Mode.COLOR:
			if color != null:
				subject.main_color = color.resolve(ctx)

		Mode.SHADER_PARAM:
			var material := subject.material_override if use_material_override else subject.node.material

			if material is ShaderMaterial:
				if shader_value_is_color:
					material.set_shader_parameter(shader_param, shader_color)
				else:
					material.set_shader_parameter(shader_param, shader_value)

		Mode.GLOW:
			ctx.battle.glow(glow_amount, glow_time, subject)

		Mode.OUTLINE:
			if outline_remove:
				if wait:
					await ctx.battle.outline_remove(subject, outline_time)
				else:
					ctx.battle.outline_remove(subject, outline_time)
			else:
				ctx.battle.outline(subject, color.resolve(ctx) if color != null else subject.main_color)
		Mode.SHAKE:
			if wait:
				await ctx.battle.shake_actor(subject, shake_amount, shake_repeat, shake_time)
			else:
				ctx.battle.shake_actor(subject, shake_amount, shake_repeat, shake_time)

		Mode.NODE_VISIBLE:
			var child := subject.node.get_node_or_null(node_path)

			if child is CanvasItem:
				child.visible = visible

		Mode.Z_INDEX:
			subject.node.z_index = z_index

		Mode.PLAY_BACKWARDS:
			subject.node.play_backwards(animation)
			if wait:
				await ctx.battle.await_anim(subject.node, animation)


func _actor(ctx: ActionSequenceContext) -> Actor:
	if actor != null:
		return actor.resolve(ctx)

	return ctx.caster


func _to_string() -> String:
	var who := str(actor) if actor != null else "Caster"

	match mode:
		Mode.ANIMATION:
			return "Set %s's animation to '%s'" % [who, animation]

		Mode.PLAY_BACKWARDS:
			return "Play '%s' backwards on %s" % [animation, who]

		Mode.VISIBLE:
			return "%s %s" % ["Show" if visible else "Hide", who]

		Mode.FRAME:
			return "Set %s to frame %d" % [who, frame]

		Mode.FLIP:
			return "Flip %s %s" % [who, "on" if flip else "off"]

		Mode.COLOR:
			return "Recolor %s" % who

		Mode.SHADER_PARAM:
			return "Set '%s' on %s's shader" % [shader_param, who]

		Mode.GLOW:
			return "Glow %s" % who

		Mode.OUTLINE:
			return "%s %s's outline" % ["Remove" if outline_remove else "Add", who]

		Mode.SHAKE:
			return "Shake %s" % who

		Mode.NODE_VISIBLE:
			return "%s '%s' on %s" % ["Show" if visible else "Hide", node_path, who]

		Mode.Z_INDEX:
			return "Set %s's z index to %d" % [who, z_index]

	return ""


func _validate_property(property: Dictionary) -> void:
	var fields: Array[String] = ["mode", "actor"]

	if property.name == "animation":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(ANIMATION_PRESETS)

	match mode:
		Mode.ANIMATION, Mode.PLAY_BACKWARDS:
			fields.append_array(["animation", "wait"])

		Mode.VISIBLE:
			fields.append("visible")

		Mode.FRAME:
			fields.append_array(["animation", "frame", "pause"])

		Mode.FLIP:
			fields.append("flip")

		Mode.COLOR:
			fields.append("color")

		Mode.SHADER_PARAM:
			fields.append_array(["shader_param", "shader_value_is_color", "use_material_override"])
			if shader_value_is_color:
				fields.append("shader_color")
			else:
				fields.append("shader_value")

		Mode.GLOW:
			fields.append_array(["glow_amount", "glow_time"])

		Mode.OUTLINE:
			fields.append_array(["color", "outline_remove", "outline_time", "wait"])

		Mode.SHAKE:
			fields.append_array(["shake_amount", "shake_repeat", "shake_time", "wait"])

		Mode.NODE_VISIBLE:
			fields.append_array(["node_path", "visible"])

		Mode.Z_INDEX:
			fields.append("z_index")

	StepEditor.only(property, fields)


func _icon() -> String:
	return "Sprite2D"
