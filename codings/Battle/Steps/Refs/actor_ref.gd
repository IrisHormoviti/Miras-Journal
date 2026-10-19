@tool
extends Resource
class_name ActorRef

enum Mode {
	CASTER,
	TARGET,
	CODENAME,
	PARTY_MEMBER,
	LOWEST_HP_ALLY,
	LOWEST_HP_ENEMY,
	RANDOM_ENEMY,
	RANDOM_ALLY,
	LOOP_ACTOR,
	LAST_ACTOR,
	ABILITY_INFLICTER,
	SUMMONED_ALLY,
	RANDOM_SUMMONED_ALLY,
}

@export var mode: Mode = Mode.CASTER:
	set(value):
		mode = value
		resource_name = str(self)
		notify_property_list_changed()
@export var codename: StringName = &"":
	set(value):
		codename = value
		resource_name = str(self)

## Zero based party slot, where `0` is the leader.
@export_enum("Leader", "Member 1", "Member 2", "Member 3") var party_index := 0:
	set(value):
		party_index = value
		resource_name = str(self)
@export var exclude_caster := false
@export var summon_index := 0


func _init(p_mode: Mode = Mode.CASTER) -> void:
	mode = p_mode


func resolve(ctx: ActionSequenceContext) -> Actor:
	if ctx == null:
		return null

	match mode:
		Mode.CASTER:
			return ctx.caster

		Mode.TARGET:
			return ctx.target

		Mode.CODENAME:
			return ctx.battle.get_actor(codename)

		Mode.PARTY_MEMBER:
			return Party.get_member_index(party_index)

		Mode.LOWEST_HP_ALLY:
			return _lowest_health(_ally_faction(ctx), ctx.caster, exclude_caster)

		Mode.LOWEST_HP_ENEMY:
			return _lowest_health(_enemy_faction(ctx), ctx.caster, false)

		Mode.RANDOM_ENEMY:
			return _random(_enemy_faction(ctx), ctx.caster, false)

		Mode.RANDOM_ALLY:
			return _random(_ally_faction(ctx), ctx.caster, exclude_caster)

		Mode.LOOP_ACTOR:
			return ctx.loop_actor

		Mode.LAST_ACTOR:
			return ctx.last_actor

		Mode.ABILITY_INFLICTER:
			if ctx.last_state != null and ctx.last_state.inflicter != null:
				return ctx.last_state.inflicter

			return ctx.caster

		Mode.SUMMONED_ALLY:
			return _summon(ctx, false)

		Mode.RANDOM_SUMMONED_ALLY:
			return _summon(ctx, true)

	return null


func _ally_faction(ctx: ActionSequenceContext) -> Array[Actor]:
	return ctx.battle.get_ally_faction(ctx.caster)


func _enemy_faction(ctx: ActionSequenceContext) -> Array[Actor]:
	return ctx.battle.get_opposing_faction(ctx.caster)


func _lowest_health(actors: Array[Actor], caster: Actor, exclude: bool) -> Actor:
	var candidates: Array[Actor] = []

	for actor in actors:
		if actor == null or not is_instance_valid(actor):
			continue

		if exclude and actor == caster:
			continue

		candidates.append(actor)

	if candidates.is_empty():
		return null

	candidates.sort_custom(func(a: Actor, b: Actor) -> bool: return a.Health < b.Health)
	return candidates[0]


func _random(actors: Array[Actor], caster: Actor, exclude: bool) -> Actor:
	var candidates: Array[Actor] = []

	for actor in actors:
		if actor == null or not is_instance_valid(actor):
			continue

		if exclude and actor == caster:
			continue

		candidates.append(actor)

	if candidates.is_empty():
		return null

	return candidates.pick_random()


func _summon(ctx: ActionSequenceContext, random: bool) -> Actor:
	if ctx.caster == null or ctx.caster.SummonedAllies.is_empty():
		return null

	if random:
		return ctx.caster.SummonedAllies.pick_random()

	var index := clampi(summon_index, 0, ctx.caster.SummonedAllies.size() - 1)
	return ctx.caster.SummonedAllies[index]


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]

	match mode:
		Mode.CODENAME:
			visible.append("codename")

		Mode.PARTY_MEMBER:
			visible.append("party_index")

		Mode.LOWEST_HP_ALLY, Mode.RANDOM_ALLY:
			visible.append("exclude_caster")

		Mode.SUMMONED_ALLY:
			visible.append("summon_index")

	StepEditor.only(property, visible)


func _to_string() -> String:
	if mode == Mode.CODENAME:
		return codename

	if mode == Mode.PARTY_MEMBER:
		if party_index == 0: return "Party Leader"
		return "Party Member %d" % (party_index)

	return str(Mode.find_key(mode)).capitalize()
