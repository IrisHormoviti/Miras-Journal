@tool
extends BattleStep
class_name TurnStep

enum Mode {
	USE_ABILITY,
	FORCE_NEXT,
	SKIP,
	RESORT,
	CANCEL_FOLLOW_UP,
}

@export var mode: Mode = Mode.USE_ABILITY:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var ability: Ability
@export var target: ActorRef
@export var consume_turn := false


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.caster

	match mode:
		Mode.USE_ABILITY:
			var victim := target.resolve(ctx) if target != null else ctx.target
			await ctx.battle.use_ability_now(subject, ability, victim, consume_turn)
		Mode.FORCE_NEXT:
			ctx.battle.force_next_actor(subject)
		Mode.SKIP:
			ctx.battle.skip_next_turn(subject)
		Mode.RESORT:
			ctx.battle.resort_turn_order()
		Mode.CANCEL_FOLLOW_UP:
			ctx.battle.cancel_follow_up()


func _to_string() -> String:
	var who := str(actor) if actor != null else "Caster"
	var victim := str(target) if target != null else "Target"

	match mode:
		Mode.USE_ABILITY:
			var ability_name := ability.name if ability != null else "an ability"
			return "Make %s use %s on %s" % [who, ability_name, victim]

		Mode.FORCE_NEXT:
			return "Send %s next" % who

		Mode.SKIP:
			return "Skip %s's turn" % who

		Mode.RESORT:
			return "Resort the turn order"

		Mode.CANCEL_FOLLOW_UP:
			return "Cancel the follow-up"

	return ""


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode", "actor"]
	match mode:
		Mode.USE_ABILITY:
			visible.append_array(["ability", "target", "consume_turn"])
		Mode.FORCE_NEXT, Mode.SKIP, Mode.RESORT, Mode.CANCEL_FOLLOW_UP:
			pass
	StepEditor.only(property, visible)


func _icon() -> String:
	return "Timer"
