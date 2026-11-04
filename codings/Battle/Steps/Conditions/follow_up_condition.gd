@tool
extends BattleCondition
class_name FollowUpCondition

## Matches the extra turn granted after an Aura Break. The actor gets to move
## again, but it is a single action rather than a full boss turn pattern.


func check(ctx: ActionSequenceContext) -> bool:
	return ctx.battle != null and ctx.battle.follow_up_turn


func _to_string() -> String:
	return "a follow-up turn"


func _icon() -> String:
	return "History"
