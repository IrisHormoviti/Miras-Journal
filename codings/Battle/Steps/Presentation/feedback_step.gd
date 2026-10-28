@tool
extends BattleStep
class_name FeedbackStep

enum Mode {
	EFFECT,
	POPUP,
	BATTLE_MESSAGE,
}

@export var mode: Mode = Mode.EFFECT:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var position: PositionRef
@export var value: StringName = &""
@export var message: String = ""
@export var insert: ActorRef
@export var insert2: ActorRef
## Use the last state touched by a previous step as the message's first insert.
@export var insert_state := false
@export var color: ColorRef
@export var offset := Vector2.ZERO
@export var flip_on_player_use := false
@export var dont_free := false
## When false, the next step starts while the effect continues.
@export var wait := false


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.target

	match mode:
		Mode.EFFECT:
			var effect_target: Variant = subject
			if position != null:
				effect_target = position.resolve(ctx, subject)
			if wait:
				await ctx.battle.play_effect(str(value), effect_target, offset, flip_on_player_use, dont_free)
			else:
				ctx.battle.play_effect(str(value), effect_target, offset, flip_on_player_use, dont_free)
			if ctx.battle.act != null:
				ctx.last_effect = ctx.battle.act.get_node_or_null(String(value))
		Mode.POPUP:
			if subject != null:
				ctx.battle.pop_num(subject, str(value), color.resolve(ctx) if color != null else Color.WHITE)
		Mode.BATTLE_MESSAGE:
			var first := ""
			var second := ""
			if insert_state and ctx.last_state != null:
				first = ctx.last_state.name
			if insert != null:
				var first_actor := insert.resolve(ctx)
				if first_actor != null:
					first = first_actor.first_name
			if insert2 != null:
				var second_actor := insert2.resolve(ctx)
				if second_actor != null:
					second = second_actor.first_name
			ctx.battle.battle_msg(message, first, second)


func _to_string() -> String:
	var who := str(actor) if actor != null else "Target"

	match mode:
		Mode.EFFECT:
			return "Play effect '%s' on %s" % [value, who]

		Mode.POPUP:
			return "Popup '%s' on %s" % [value, who]

		Mode.BATTLE_MESSAGE:
			return "Message \"%s\"" % message

	return ""


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]
	match mode:
		Mode.EFFECT:
			visible.append_array(["actor", "position", "value", "offset", "flip_on_player_use", "dont_free", "wait"])
		Mode.POPUP:
			visible.append_array(["actor", "value", "color"])
		Mode.BATTLE_MESSAGE:
			visible.append_array(["message", "insert", "insert2", "insert_state"])
	StepEditor.only(property, visible)


func _icon() -> String:
	return "GPUParticles2D"
