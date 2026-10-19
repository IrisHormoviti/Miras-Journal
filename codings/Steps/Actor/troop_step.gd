@tool
extends BattleStep
class_name TroopStep

enum Mode {
	ADD,
	REMOVE,
	KILL,
}

@export var mode: Mode = Mode.ADD:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.target

	if subject == null:
		return

	match mode:
		Mode.ADD:
			ctx.last_actor = await ctx.battle.add_to_troop(subject)

		Mode.REMOVE:
			ctx.battle.Troop.erase(subject)
			ctx.battle.TurnOrder.erase(subject)
			if subject.node != null:
				subject.node.queue_free()

			ctx.battle.resort_turn_order()

		Mode.KILL:
			await ctx.battle.death(subject)


func _to_string() -> String:
	var who := str(actor) if actor != null else "Target"

	match mode:
		Mode.ADD:
			return "Add %s to the troop" % who

		Mode.REMOVE:
			return "Remove %s from the troop" % who

		Mode.KILL:
			return "Kill %s" % who

	return ""


func _icon() -> String:
	return "SkeletonPreview"
