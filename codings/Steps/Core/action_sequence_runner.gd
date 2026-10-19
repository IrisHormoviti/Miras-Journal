extends Node
class_name ActionSequenceRunner

var battle: Battle
var debug_logging := false
var seq_running := 0


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
		await _run_aoe(ability, ctx)
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

	if not target.CantDodge or target.has_state("Bound") or target.has_state("Soaked"):
		if randf_range(0, 1) > ability.SucessChance and not battle.no_misses:
			ctx.roll = HitOutcome.MISS

	if ctx.roll != HitOutcome.MISS and randf_range(0, 1) < ability.CritChance and not battle.no_crits:
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


func _run_aoe(ability: Ability, base: ActionSequenceContext) -> void:
	var launcher := ability.action_sequence
	if launcher != null and not launcher.steps.is_empty():
		var launcher_ctx := base.duplicate_for_target(base.caster)
		launcher_ctx.is_launcher = true
		if _has_damage(launcher):
			roll(launcher_ctx, base.caster)
		battle.hold_turn()
		await run_sequence(launcher, launcher_ctx)
		battle.release_turn()

	var per_target := ability.aoe_sequence
	if per_target == null or per_target.steps.is_empty():
		per_target = ability.action_sequence

	if per_target == null or per_target.steps.is_empty():
		return

	var targets: Array[Actor] = battle.get_target_faction(ability).duplicate()
	if base.caster in targets:
		targets.erase(base.caster)

	for target: Actor in targets:
		if target == null or not is_instance_valid(target):
			continue

		if battle.act != null:
			battle.act.interrupted = false
		var target_ctx := base.duplicate_for_target(target)
		roll(target_ctx, target)

		seq_running += 1
		battle.hold_turn()
		_run_target(per_target, target_ctx)
		await Event.wait(ability.AOE_Stagger)

	while seq_running > 0:
		await Event.wait()


func _run_target(sequence: ActionSequence, ctx: ActionSequenceContext) -> void:
	await run_sequence(sequence, ctx)
	battle.release_turn()
	seq_running = maxi(0, seq_running - 1)


func _has_damage(sequence: ActionSequence) -> bool:
	for step in sequence.walk():
		if step is DamageStep:
			return true
	return false


func _wait(seconds: float) -> void:
	await battle.get_tree().create_timer(seconds).timeout
