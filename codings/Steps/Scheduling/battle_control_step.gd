@tool
extends BattleStep
class_name BattleControlStep

enum Mode {
	VICTORY,
	DEFEAT,
	END,
	NO_MISSES,
	NO_CRITS,
	AWAIT_VICTORY,
}

@export var mode: Mode = Mode.VICTORY:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var silent := false
@export var value := true


func run(ctx: ActionSequenceContext) -> void:
	match mode:
		Mode.VICTORY:
			ctx.battle.victory(silent)
		Mode.DEFEAT:
			var subject := actor.resolve(ctx) if actor != null else ctx.target
			ctx.battle.game_over(subject)
		Mode.END:
			ctx.battle.end_battle()
		Mode.NO_MISSES:
			ctx.battle.no_misses = value
		Mode.NO_CRITS:
			ctx.battle.no_crits = value
		Mode.AWAIT_VICTORY:
			await Global.battle_end


func _to_string() -> String:
	match mode:
		Mode.VICTORY:
			return "Silent victory" if silent else "Victory"

		Mode.DEFEAT:
			return "Defeat %s" % (str(actor) if actor != null else "Target")

		Mode.END:
			return "End the battle"

		Mode.NO_MISSES:
			return "No misses: %s" % ("on" if value else "off")

		Mode.NO_CRITS:
			return "No crits: %s" % ("on" if value else "off")

		Mode.AWAIT_VICTORY:
			return "Await the victory screen"

	return ""


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]
	match mode:
		Mode.VICTORY:
			visible.append("silent")
		Mode.DEFEAT:
			visible.append("actor")
		Mode.NO_MISSES, Mode.NO_CRITS:
			visible.append("value")
		Mode.END, Mode.AWAIT_VICTORY:
			pass
	StepEditor.only(property, visible)


func _icon() -> String:
	return "Control"
