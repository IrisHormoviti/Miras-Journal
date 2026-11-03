extends Node
class_name ActionSequenceRunner

var battle: Battle
var debug_logging := false


func run_ability(ability: Ability, caster: Actor, target: Actor, finish_turn := true) -> void:
	if ability == null or caster == null:
		if finish_turn and battle != null:
			battle.end_turn()
		return

	battle.Action = true
	if caster.node != null:
		caster.node.z_index = 1
	if battle.act != null:
		battle.act.interrupted = false

	Loader.battle_bars(2)
	var ctx := _make_context(ability, caster, target)

	if ability.is_aoe():
		# The sequence starts on the caster; a ForEachActorStep picks the actual
		# targets and rolls each one separately.
		ctx.target = caster

		if _has_damage(ability.action_sequence):
			roll(ctx, caster)
	else:
		roll(ctx, target)

	await _run_single(ability.action_sequence, ctx)

	if finish_turn:
		battle.anim("", caster)
		battle.end_turn()


## Runs a trap's sequence with the outcome already rolled by trigger_trap.
func run_trap(ability: Ability, caster: Actor, target: Actor, outcome: int) -> void:
	if ability == null or ability.action_sequence == null or ability.action_sequence.is_empty():
		return

	var ctx := _make_context(ability, caster, target)
	ctx.roll = outcome
	await _run_single(ability.action_sequence, ctx)


func run_action_sequence(sequence: ActionSequence, ctx: ActionSequenceContext) -> void:
	await run_sequence(sequence, ctx)


func run_sequence(sequence: ActionSequence, ctx: ActionSequenceContext) -> void:
	if sequence == null or sequence.steps.is_empty():
		return

	var previous := ctx.sequence
	ctx.sequence = sequence
	await run_steps(sequence.steps, ctx)
	ctx.sequence = previous


func run_steps(steps: Array[BattleStep], ctx: ActionSequenceContext) -> void:
	for step in steps:
		if step == null:
			continue
		await run_step(step, ctx)


func run_step(step: BattleStep, ctx: ActionSequenceContext) -> void:
	if debug_logging:
		print_rich("[color=cornflower-blue]Step: ", step.get_script().resource_path.get_file(), " ", step.note)

	@warning_ignore("redundant_await")
	await step.run(ctx)


func roll(ctx: ActionSequenceContext, target: Actor) -> void:
	ctx.roll = HitOutcome.HIT
	var ability := ctx.ability
	if ability == null or target == null:
		return

	if not target.cant_dodge or target.has_state("Bound") or target.has_state("Soaked"):
		if randf_range(0, 1) > ability.success_chance and not battle.no_misses:
			ctx.roll = HitOutcome.MISS

	if ctx.roll != HitOutcome.MISS and randf_range(0, 1) < ability.crit_chance and not battle.no_crits:
		ctx.roll = HitOutcome.CRIT

	if battle.act != null:
		battle.act.miss = ctx.roll == HitOutcome.MISS
		battle.act.crit = ctx.roll == HitOutcome.CRIT


func _make_context(ability: Ability, caster: Actor, target: Actor) -> ActionSequenceContext:
	var ctx := ActionSequenceContext.new()
	ctx.battle = battle
	ctx.runner = self
	ctx.ability = ability
	ctx.caster = caster
	ctx.target = target
	ctx.home_position = battle.initial
	return ctx


func _run_single(sequence: ActionSequence, ctx: ActionSequenceContext) -> void:
	if sequence == null or sequence.steps.is_empty():
		return

	battle.hold_turn()
	await run_sequence(sequence, ctx)
	battle.release_turn()


func _has_damage(sequence: ActionSequence) -> bool:
	if sequence == null:
		return false

	for step in sequence.walk():
		if step is DamageStep:
			return true
	return false
