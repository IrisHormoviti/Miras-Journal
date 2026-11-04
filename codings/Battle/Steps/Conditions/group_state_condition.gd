@tool
extends BattleCondition
class_name GroupStateCondition

enum GroupMatch {
	ANY,
	ALL,
}

@export var group: ActorGroup.Kind = ActorGroup.Kind.ALLIES
@export var include_dead := false
@export var state: StringName = &""
@export var present := true
@export var group_match: GroupMatch = GroupMatch.ANY


func check(ctx: ActionSequenceContext) -> bool:
	var actors := ActorGroup.resolve(ctx, group, include_dead)

	if actors.is_empty():
		return false

	for target in actors:
		var has := target.has_state(str(state))

		# Death is asynchronous: health drops to zero immediately, but the
		# KnockedOut state is only added after the actor's other states have
		# finished clearing. Treat zero health as knocked out so conditions
		# like Heat Wave's "nothing happened" check don't fire in that gap.
		if not has and state == &"KnockedOut" and target.health <= 0:
			has = true

		if group_match == GroupMatch.ANY and has == present:
			return true

		if group_match == GroupMatch.ALL and has != present:
			return false

	return group_match == GroupMatch.ALL


func _to_string() -> String:
	return "%s %s %s state %s" % [
		enum_label(ActorGroup.Kind, group),
		"all" if group_match == GroupMatch.ALL else "any",
		"have" if present else "lack",
		state,
	]


func _icon() -> String:
	return "Group"
