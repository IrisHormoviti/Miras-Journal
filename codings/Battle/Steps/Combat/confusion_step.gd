@tool
extends BattleStep
class_name ConfusionStep

## Legacy-compatible Confused turn: rolls against the state's turn counter and
## may make the actor attack a random target. The state is read from
## [member ActionSequenceContext.last_state].
func run(ctx: ActionSequenceContext) -> void:
	var chara := ctx.target if ctx.target != null else ctx.caster
	var state := ctx.last_state

	if chara == null or state == null:
		return

	var luck := randi_range(state.turns, 1)

	if luck < -1:
		await chara.remove_state(state, ctx, true)
		ctx.battle.battle_msg("confusion_recover")
	elif luck == -1 or not chara.controllable:
		var choices: Array[Ability] = chara.abilities.duplicate()
		choices.append(chara.standard_attack)
		chara.next_move = choices.pick_random()
		chara.next_action = Actor.BtAction.MAGIC
		chara.next_target = ctx.battle.TurnOrder.pick_random()

		if chara.controllable:
			ctx.battle.battle_msg("confusion_lose_control")
		elif chara == chara.next_target and chara.next_move.target == Ability.T.ONE_ENEMY:
			ctx.battle.battle_msg("confusion_hit_self")
		elif chara.next_target in ctx.battle.get_ally_faction(chara) and chara.next_move.target == Ability.T.ONE_ENEMY:
			ctx.battle.battle_msg("confusion_hit_ally")

	state.turns -= 1


func _to_string() -> String:
	return "Roll confusion"


func _icon() -> String:
	return "RandomNumberGenerator"
