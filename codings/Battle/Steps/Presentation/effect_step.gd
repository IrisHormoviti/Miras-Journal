@tool
extends BattleStep
class_name EffectStep

enum Mode {
	PLAY,
	ANIM,
	MOVE,
	FREE,
	SET_SHADER,
}

@export var mode: Mode = Mode.PLAY:
	set(value):
		mode = value
		notify_property_list_changed()
@export var effect_name: StringName = &""
@export var target := ActorRef.new(ActorRef.Mode.TARGET)
@export var position: PositionRef
@export var offset := Vector2.ZERO
@export var flip_on_player_use := false
## When false, the next step starts while the effect continues.
@export var wait := false
@export var animation: StringName = &""
@export var backwards := false
@export var duration := 0.1
@export var shader: Shader
@export var prev_color := Color.WHITE
@export var new_color: ColorRef


func run(ctx: ActionSequenceContext) -> void:
	if mode == Mode.PLAY:
		await _play(ctx)
		return

	var effect := _effect(ctx)

	if effect == null:
		return

	match mode:
		Mode.ANIM:
			if backwards:
				effect.play_backwards(animation)
			else:
				effect.play(animation)

			if wait:
				await ctx.battle.await_anim(effect, animation)

		Mode.MOVE:
			var destination := position.resolve(ctx) if position != null else effect.position

			if wait:
				await Battle.tween(effect, "global_position", destination, duration, Tween.EASE_OUT, Tween.TRANS_QUART)
			else:
				Battle.tween(effect, "global_position", destination, duration, Tween.EASE_OUT, Tween.TRANS_QUART)

		Mode.FREE:
			effect.queue_free()

		Mode.SET_SHADER:
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("prev_color", prev_color)
			material.set_shader_parameter("new_color", new_color.resolve(ctx) if new_color != null else Color.WHITE)
			effect.material = material


func _play(ctx: ActionSequenceContext) -> void:
	var effect_target: Variant = ctx.target

	var offsetized: Vector2 = Vector2(
		ctx.battle.offsetize(offset.x, ctx.caster) if flip_on_player_use else offset.x,
		offset.y
	)

	if target != null:
		effect_target = target.resolve(ctx)

	if position != null:
		effect_target = position.resolve(ctx, ctx.target)

	if wait:
		await ctx.battle.play_effect(str(effect_name), effect_target, offsetized, flip_on_player_use, true)
	else:
		ctx.battle.play_effect(str(effect_name), effect_target, offsetized, flip_on_player_use, true)

	if ctx.battle.act != null:
		ctx.last_effect = ctx.battle.act.get_node_or_null(str(effect_name))


func _effect(ctx: ActionSequenceContext) -> AnimatedSprite2D:
	if ctx.last_effect != null and is_instance_valid(ctx.last_effect):
		return ctx.last_effect

	if ctx.battle.act == null:
		return null

	return ctx.battle.act.get_node_or_null(str(effect_name)) as AnimatedSprite2D


func _to_string() -> String:
	var label := "effect"

	match mode:
		Mode.PLAY:
			label = "Play effect"

		Mode.ANIM:
			return "Change effect %s into %s" % [effect_name, animation]

		Mode.MOVE:
			label = "Move effect"

		Mode.FREE:
			label = "Free effect"

		Mode.SET_SHADER:
			label = "Set effect shader"

	if str(effect_name).is_empty():
		return label

	return "%s '%s'" % [label, effect_name]


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode", "effect_name"]

	match mode:
		Mode.PLAY:
			visible.append_array(["target", "position", "offset", "flip_on_player_use", "wait"])

		Mode.ANIM:
			visible.append_array(["animation", "backwards", "wait"])

		Mode.MOVE:
			visible.append_array(["position", "duration", "wait"])

		Mode.FREE:
			pass

		Mode.SET_SHADER:
			visible.append_array(["shader", "prev_color", "new_color"])

	StepEditor.only(property, visible)


func _icon() -> String:
	return "GPUParticles2D"
