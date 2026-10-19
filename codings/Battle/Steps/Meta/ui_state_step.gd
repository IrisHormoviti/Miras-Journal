@tool
extends BattleStep
class_name UIStateStep

enum Mode {
	HUD_PARTY,
	HUD_BATTLE_STATE,
	ENEMY_UI,
	COMMAND_ENABLED,
	CHECK,
	CANVAS_LAYER,
	FOLLOW_UP,
}

@export var mode: Mode = Mode.HUD_PARTY:
	set(value):
		mode = value
		notify_property_list_changed()
@export var enabled := true
@export var ability := true
@export var command := true
@export var item := true
@export var attack := true
@export var layer := 1
@export var node_path: NodePath = ^"Can"


func run(ctx: ActionSequenceContext) -> void:
	match mode:
		Mode.HUD_PARTY:
			Hud._check_party()
		Mode.HUD_BATTLE_STATE:
			Hud.battle_state(enabled)
		Mode.ENEMY_UI:
			ctx.battle.enemy_ui.visible = enabled
		Mode.COMMAND_ENABLED:
			ctx.battle.ui.disable_ability = not ability
			ctx.battle.ui.disable_command = not command
			ctx.battle.ui.disable_item = not item
			ctx.battle.ui.disable_attack = not attack
		Mode.CHECK:
			Global.check.emit()
		Mode.CANVAS_LAYER:
			var canvas := Loader.get_node(str(node_path))
			if canvas is CanvasLayer:
				canvas.layer = layer
		Mode.FOLLOW_UP:
			ctx.battle.follow_up_text()


func _to_string() -> String:
	match mode:
		Mode.HUD_PARTY:
			return "Refresh the party HUD"

		Mode.HUD_BATTLE_STATE:
			return "Battle state HUD: %s" % ("on" if enabled else "off")

		Mode.ENEMY_UI:
			return "Enemy UI: %s" % ("on" if enabled else "off")

		Mode.COMMAND_ENABLED:
			var disabled := PackedStringArray()

			if not ability:
				disabled.append("ability")

			if not command:
				disabled.append("command")

			if not item:
				disabled.append("item")

			if not attack:
				disabled.append("attack")

			if disabled.is_empty():
				return "Enable every command"

			return "Disable %s" % ", ".join(disabled)

		Mode.CHECK:
			return "Emit the check signal"

		Mode.CANVAS_LAYER:
			return "Set '%s' to layer %d" % [node_path, layer]

		Mode.FOLLOW_UP:
			return "Show the follow-up text"

	return ""


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]
	match mode:
		Mode.HUD_PARTY, Mode.CHECK, Mode.FOLLOW_UP:
			pass
		Mode.HUD_BATTLE_STATE, Mode.ENEMY_UI:
			visible.append("enabled")
		Mode.COMMAND_ENABLED:
			visible.append_array(["ability", "command", "item", "attack"])
		Mode.CANVAS_LAYER:
			visible.append_array(["layer", "node_path"])
	StepEditor.only(property, visible)


func _icon() -> String:
	return "Control"
