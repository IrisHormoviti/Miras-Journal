extends Node

## This script is totally not vibecoded

## Headless battle harness.
##
## It drives the same standalone preview path the battle step editor uses: it
## writes the preview request and sequence, launches Battle.tscn on its own, and
## then asserts against the live battle. Run it with:
##
##     godot --headless --path . res://codings/Battle/BattleHeadlessTest.tscn
##
## The scene quits with a nonzero exit code when a check fails.

const BATTLE_SCENE := preload("res://codings/Battle/Battle.tscn")
const ZAPPED := preload("res://database/States/Zapped.tres")
const ICY_DRIZZLE := preload("res://database/Abilities/IcyDrizzle.tres")
const TEST_DAMAGE := 5

var battle: Battle
var failed := false


func _ready() -> void:
	Battle.headless_driver = true

	# Write the same request the inspector preview writes, then run the battle
	# scene standalone so testing and previewing share one code path.
	var steps := _preview_steps()

	if not Battle.write_preview(
		Battle.preview_shared_dir_static(),
		steps,
		{"outcome": 0, "actor": "Mira", "targets": 2},
	):
		_fail("Could not write the preview request")
		get_tree().quit(1)
		return

	battle = BATTLE_SCENE.instantiate()
	add_child(battle)

	await get_tree().create_timer(3.0).timeout

	if not is_instance_valid(battle) or battle.Troop.is_empty():
		_fail("Battle harness failed to start")
		get_tree().quit(1)
		return

	print("BATTLE_TEST_READY")
	await _test_action()
	await _test_damage_and_state()
	await _test_state_wait()
	await _test_aoe()
	await _test_trap_interrupt()
	await _test_miss()
	await _test_auto_idle()
	_test_branch_outcomes()

	print("BATTLE_TEST_DONE failed=", failed)
	get_tree().quit(1 if failed else 0)


## The preview sequence used to boot the standalone battle.
func _preview_steps() -> Array[BattleStep]:
	var steps: Array[BattleStep] = [_damage_step(TEST_DAMAGE)]
	return steps


func _damage_step(power: int) -> DamageStep:
	var damage := DamageStep.new()
	var value := ValueRef.new()
	value.source = ValueRef.Source.FIXED
	value.value = power
	damage.power = value
	damage.magic_mode = DamageStep.MagicMode.PHYSICAL
	return damage


func _state_step(state: State, wait := true) -> StateStep:
	var step := StateStep.new()
	step.mode = StateStep.Mode.ADD
	step.state = state
	step.wait = wait
	return step


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _test_action() -> void:
	var caster := Party.Leader
	var target := battle.Troop[0]

	if caster == null or target == null:
		_fail("Battle harness has no caster or target")
		return

	var ability := Ability.nothing().duplicate()
	ability.name = "BattleTestHit"

	var sequence := ActionSequence.new()
	var wait := WaitStep.new()
	wait.duration = 0.1
	sequence.steps.append(wait)
	sequence.steps.append(_damage_step(TEST_DAMAGE))
	ability.action_sequence = sequence

	var before := target.Health
	await battle.use_ability_now(caster, ability, target)
	var after := target.Health
	print("BATTLE_TEST_HIT before=", before, " after=", after)

	if after >= before:
		_fail("Battle harness did not deal damage")

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Battle harness left the turn locked")


func _test_damage_and_state() -> void:
	var target := battle.Troop[0]

	if target == null:
		_fail("Battle harness has no target for damage and state")
		return

	var ability := Ability.nothing().duplicate() as Ability
	ability.name = "BattleTestDamageState"
	ability.success_chance = 1
	ability.crit_chance = 1
	battle.no_misses = true
	battle.no_crits = false

	var sequence := ActionSequence.new()
	sequence.steps.append(_damage_step(TEST_DAMAGE))
	sequence.steps.append(_state_step(ZAPPED))
	ability.action_sequence = sequence

	var before := target.Health
	await battle.use_ability_now(Party.Leader, ability, target)
	var after := target.Health
	print("BATTLE_TEST_DAMAGE_STATE before=", before, " after=", after, " state=", target.has_state("Zapped"))

	if after >= before:
		_fail("Damage step did not deal damage")

	if not target.has_state("Zapped"):
		_fail("State step did not apply Zapped")

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Damage and state test left the turn locked")


func _test_state_wait() -> void:
	var target := battle.Troop[0]

	if target == null:
		_fail("Battle harness has no target for the state wait test")
		return

	# A waiting state step should block on the state's presentation; a
	# non-waiting one should add the state and run straight through. Measure
	# the add_state call directly so the check does not touch turn state.
	var waiting := await _measure_add_state(target, ZAPPED, true)
	var not_waiting := await _measure_add_state(target, ZAPPED, false)
	print("BATTLE_TEST_STATE_WAIT waiting=", waiting, " not_waiting=", not_waiting)

	if waiting <= not_waiting:
		_fail("Waiting state step did not block the sequence")

	if not target.has_state("Zapped"):
		_fail("State wait test did not apply the state")

	if battle.lock_turn or battle.lock_count != 0:
		_fail("State wait test left the turn locked")


## Adds [param state] to [param target] and returns how long it took, in
## milliseconds.
func _measure_add_state(target: Actor, state: State, wait: bool) -> int:
	target.remove_state(state.name)
	var started := Time.get_ticks_msec()
	await target.add_state(state, -1, Party.Leader, true, wait)
	return Time.get_ticks_msec() - started


func _test_aoe() -> void:
	if battle.Troop.size() < 2:
		_fail("Battle harness needs two enemies for AOE")
		return

	var ability := ICY_DRIZZLE.duplicate() as Ability
	ability.name = "Icy Drizzle"
	ability.success_chance = 1
	ability.crit_chance = 1
	battle.no_misses = true
	battle.no_crits = false

	var first := battle.Troop[0]
	var second := battle.Troop[1]
	var first_before := first.Health
	var second_before := second.Health
	await battle.use_ability_now(Party.Leader, ability, first)
	print("BATTLE_TEST_ICY_DRIZZLE first=", first_before, "->", first.Health, " second=", second_before, "->", second.Health)

	if first.Health >= first_before or second.Health >= second_before:
		_fail("Icy Drizzle did not damage every target")

	if not first.has_state("Frozen") or not second.has_state("Frozen"):
		_fail("Icy Drizzle did not freeze every target")

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Icy Drizzle left the turn locked")


func _test_trap_interrupt() -> void:
	if battle.Troop.size() < 2:
		_fail("Battle harness needs two enemies for trap interruption")
		return

	var first := battle.Troop[0]
	var second := battle.Troop[1]
	var trap_ability := Ability.nothing().duplicate() as Ability
	trap_ability.name = "Battle Test Trap"
	trap_ability.success_chance = 1
	var trap_sequence := ActionSequence.new()
	trap_sequence.steps.append(_damage_step(TEST_DAMAGE))
	trap_ability.action_sequence = trap_sequence

	var trap := Trap.new()
	trap.name = "Battle Test Trap"
	trap.ability = trap_ability
	var placed: Trap = await battle.apply_trap(trap, first)
	placed.inflicter = null

	var ability := Ability.nothing().duplicate() as Ability
	ability.name = "Battle Test AOE"
	ability.target = Ability.T.AOE_ENEMIES
	ability.aoe_stagger = 0.1
	ability.success_chance = 1
	var sequence := ActionSequence.new()

	for i in 2:
		sequence.steps.append(_damage_step(TEST_DAMAGE))

	ability.aoe_sequence = sequence
	battle.no_misses = true

	var first_before := first.Health
	var second_before := second.Health
	await battle.use_ability_now(Party.Leader, ability, first)
	var first_damage := first_before - first.Health
	var second_damage := second_before - second.Health
	print("BATTLE_TEST_TRAP first=", first_damage, " second=", second_damage, " pending=", battle.pending_traps.size())

	if first_damage <= 0 or second_damage <= first_damage:
		_fail("Trap did not interrupt only the hit target")

	if battle.pending_traps.size() != 1:
		_fail("Trap was not queued exactly once")

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Trap test left the turn locked")

	var caster := Party.Leader
	var caster_before := caster.Health
	await battle.resolve_traps()
	print("BATTLE_TEST_TRAP_COUNTER caster=", caster_before, "->", caster.Health)

	if caster.Health >= caster_before:
		_fail("Trap counterattack did not damage the attacker")

	if not battle.pending_traps.is_empty():
		_fail("Trap queue was not cleared")

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Trap counterattack left the turn locked")


func _test_miss() -> void:
	var target := battle.Troop[0]
	var ability := Ability.nothing().duplicate() as Ability
	ability.name = "Battle Test Miss"
	ability.success_chance = 0
	battle.no_misses = false
	battle.no_crits = false

	var damage := _damage_step(TEST_DAMAGE)
	# The miss animation holds the turn until it finishes. Waiting for it here
	# keeps the check deterministic instead of racing the detached animation.
	var miss := MissStep.new()
	miss.wait = true
	damage.miss_steps = [miss]

	var sequence := ActionSequence.new()
	sequence.steps.append(damage)
	ability.action_sequence = sequence

	var before := target.Health
	await battle.use_ability_now(Party.Leader, ability, target)
	print("BATTLE_TEST_MISS before=", before, " after=", target.Health)

	if target.Health != before:
		_fail("Battle harness miss dealt damage")

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Battle harness miss left the turn locked")


func _test_auto_idle() -> void:
	var caster := Party.Leader
	var target := battle.Troop[0]
	var ability := Ability.nothing().duplicate() as Ability
	ability.name = "Battle Test Auto Idle"

	var sequence := ActionSequence.new()
	var pose := ActorSpriteStep.new()
	pose.animation = &"Attack1"
	pose.wait = false
	sequence.steps.append(pose)
	ability.action_sequence = sequence

	await battle.use_ability_now(caster, ability, target, true)
	await get_tree().process_frame
	print("BATTLE_TEST_AUTO_IDLE animation=", caster.node.animation)

	if caster.node.animation != "Idle":
		_fail("Turn did not return the caster to idle")


func _test_branch_outcomes() -> void:
	var ctx := ActionSequenceContext.new()
	var branch := BranchStep.new()

	branch.mode = BranchStep.Mode.HIT
	ctx.roll = HitOutcome.HIT

	if not branch._matches(ctx):
		_fail("Hit branch did not match a hit")

	ctx.roll = HitOutcome.CRIT

	if not branch._matches(ctx):
		_fail("Hit branch did not match a crit")

	ctx.roll = HitOutcome.MISS

	if branch._matches(ctx):
		_fail("Hit branch matched a miss")

	branch.mode = BranchStep.Mode.CRIT
	ctx.roll = HitOutcome.HIT

	if branch._matches(ctx):
		_fail("Crit branch matched a normal hit")

	ctx.roll = HitOutcome.CRIT

	if not branch._matches(ctx):
		_fail("Crit branch did not match a crit")

	branch.mode = BranchStep.Mode.MISS
	ctx.roll = HitOutcome.CRIT

	if branch._matches(ctx):
		_fail("Miss branch matched a crit")

	ctx.roll = HitOutcome.MISS

	if not branch._matches(ctx):
		_fail("Miss branch did not match a miss")

	print("BATTLE_TEST_BRANCH_OUTCOMES ok")
