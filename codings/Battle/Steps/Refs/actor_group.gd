@tool
extends RefCounted
class_name ActorGroup

enum Kind {
	PARTY_CURRENT,
	PARTY_ALL,
	TROOP,
	ALLIES,
	ENEMIES,
	TURN_ORDER,
	TARGET_FACTION,
	ALL,
}


static func resolve(ctx: ActionSequenceContext, kind: Kind, include_dead := false) -> Array[Actor]:
	var result: Array[Actor] = []

	match kind:
		Kind.PARTY_CURRENT:
			result.append_array(Party.current)
		Kind.PARTY_ALL:
			result.append_array(Party.members)
		Kind.TROOP:
			result.append_array(ctx.battle.Troop)
		Kind.ALLIES:
			result.append_array(ctx.battle.get_ally_faction(ctx.caster, not include_dead))
		Kind.ENEMIES:
			result.append_array(ctx.battle.get_opposing_faction(ctx.caster, not include_dead))
		Kind.TURN_ORDER:
			result.append_array(ctx.battle.TurnOrder)
		Kind.TARGET_FACTION:
			result.append_array(ctx.battle.get_target_faction())
		Kind.ALL:
			result.append_array(ctx.battle.get_any_faction(not include_dead))

	var clean: Array[Actor] = []

	for actor in result:
		if actor == null or not is_instance_valid(actor):
			continue
		if not include_dead and actor.health <= 0:
			continue
		if not clean.has(actor):
			clean.append(actor)

	return clean
