@tool
extends BattleStep
class_name BattleFlowStep

enum Mode {
	ENTRANCE_ANIM,
	VICTORY_ANIM,
	VICTORY_MUSIC,
	FOLLOW_UP_TEXT,
	CLEAR_ITEMS,
	AWAIT_END,
	IN_BATTLE,
	PAUSE,
	POSITION_SPRITES,
	SPRITE_INIT,
	SET_CURRENT,
}

@export var mode: Mode = Mode.ENTRANCE_ANIM:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var enabled := true
## When false, entrance and victory animations play in the background.
@export var wait := true


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.target

	match mode:
		Mode.ENTRANCE_ANIM:
			if subject != null:
				if wait:
					await ctx.battle.entrance_anim(subject)
				else:
					ctx.battle.entrance_anim(subject)
		Mode.VICTORY_ANIM:
			if subject != null:
				if wait:
					await ctx.battle.victory_anim(subject)
				else:
					ctx.battle.victory_anim(subject)
		Mode.VICTORY_MUSIC:
			ctx.battle.victory_music()
		Mode.FOLLOW_UP_TEXT:
			ctx.battle.follow_up_text()
		Mode.CLEAR_ITEMS:
			ctx.battle.ObtainedItems.clear()
		Mode.AWAIT_END:
			await Global.battle_end
		Mode.IN_BATTLE:
			Battle.in_battle = enabled
		Mode.PAUSE:
			ctx.battle.get_tree().paused = enabled
		Mode.POSITION_SPRITES:
			ctx.battle.position_sprites()
		Mode.SPRITE_INIT:
			if subject != null:
				ctx.battle.sprite_init(subject)

		Mode.SET_CURRENT:
			if subject != null:
				ctx.battle.CurrentChar = subject

				if ctx.battle.act != null:
					ctx.battle.act.CurrentChar = subject


func _to_string() -> String:
	var who := str(actor) if actor != null else "Target"

	match mode:
		Mode.ENTRANCE_ANIM:
			return "Entrance animation for %s" % who

		Mode.VICTORY_ANIM:
			return "Victory animation for %s" % who

		Mode.VICTORY_MUSIC:
			return "Play the victory music"

		Mode.FOLLOW_UP_TEXT:
			return "Show the follow-up text"

		Mode.CLEAR_ITEMS:
			return "Clear the obtained items"

		Mode.AWAIT_END:
			return "Await the battle end"

		Mode.IN_BATTLE:
			return "In battle: %s" % ("on" if enabled else "off")

		Mode.PAUSE:
			return "Pause the tree: %s" % ("on" if enabled else "off")

		Mode.POSITION_SPRITES:
			return "Position the sprites"

		Mode.SPRITE_INIT:
			return "Initialize the sprite for %s" % who

		Mode.SET_CURRENT:
			return "Make %s the current actor" % who

	return ""


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]
	match mode:
		Mode.ENTRANCE_ANIM, Mode.VICTORY_ANIM:
			visible.append_array(["actor", "wait"])
		Mode.SPRITE_INIT, Mode.SET_CURRENT:
			visible.append("actor")
		Mode.IN_BATTLE, Mode.PAUSE:
			visible.append("enabled")
		Mode.VICTORY_MUSIC, Mode.FOLLOW_UP_TEXT, Mode.CLEAR_ITEMS, Mode.AWAIT_END, Mode.POSITION_SPRITES:
			pass
	StepEditor.only(property, visible)


func _icon() -> String:
	return "CanvasItem"
