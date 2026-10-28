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
	await _test_shared_state()
	await _test_teleport()
	await _test_side_aware_positions()
	await _test_aoe()
	await _test_trap_interrupt()
	await _test_miss()
	await _test_auto_idle()
	await _test_state_pose()
	_test_enemy_preview_setup()
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

	var before := target.health
	await battle.use_ability_now(caster, ability, target)
	var after := target.health
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

	var before := target.health
	await battle.use_ability_now(Party.Leader, ability, target)
	var after := target.health
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


func _test_shared_state() -> void:
	if battle.Troop.size() < 2:
		_fail("Battle harness needs two enemies for the shared state test")
		return

	var first := battle.Troop[0]
	var second := battle.Troop[1]
	var burned: State = load("res://database/States/Burned.tres")
	await first.add_state(burned, -1, Party.Leader, false, false)
	await second.add_state(burned, -1, Party.Leader, false, false)

	var first_state := first.get_state("Burned")
	var second_state := second.get_state("Burned")
	var distinct := first_state != second_state
	print("BATTLE_TEST_SHARED_STATE distinct=", distinct)

	if not distinct:
		_fail("Two actors share the same State instance")

	# Expiring the state on one actor must not queue it for removal on another.
	first_state.queue_remove = true
	battle.remove_queued_states(first)

	if not second.has_state("Burned"):
		_fail("Removing a state from one actor removed it from another")

	battle.remove_queued_states(second)

	if not second.has_state("Burned"):
		_fail("A shared queue_remove flag removed the state on the second actor")

	# Removing through the ability's own resource must still find the copy.
	second.remove_state(burned)

	if second.has_state("Burned"):
		_fail("Removing a state by resource did not remove the actor's copy")

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Shared state test left the turn locked")


func _test_teleport() -> void:
	var caster := Party.Leader

	if caster == null or caster.node == null:
		_fail("Battle harness has no caster for the teleport test")
		return

	var start := caster.node.position
	var expected := start + Vector2(20, -5)
	var step := MoveStep.new()
	step.mode = MoveStep.Mode.TELEPORT
	step.destination = PositionRef.new(PositionRef.Mode.ABSOLUTE)
	step.destination.position = expected

	var ability := Ability.nothing().duplicate() as Ability
	ability.name = "BattleTestTeleport"
	var sequence := ActionSequence.new()
	sequence.steps.append(step)
	ability.action_sequence = sequence

	await battle.use_ability_now(caster, ability, battle.Troop[0])
	print("BATTLE_TEST_TELEPORT at=", caster.node.position, " expected=", expected)

	if caster.node.position != expected:
		_fail("MoveStep teleport did not snap the actor to the destination")

	caster.node.position = start

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Teleport test left the turn locked")


func _test_side_aware_positions() -> void:
	var ability: Ability = load("res://database/Abilities/Attacks/WarpAttack.tres")
	var walk: MoveStep = null
	var teleports: Array[MoveStep] = []

	for step in ability.action_sequence.walk():
		if step is MoveStep and step.mode == MoveStep.Mode.WALK and walk == null:
			walk = step
		elif step is MoveStep and step.mode == MoveStep.Mode.TELEPORT:
			teleports.append(step)

	if walk == null or teleports.size() < 2:
		_fail("Warp Attack is missing its walk or teleport steps")
		return

	var ally := Party.Leader
	var enemy := battle.Troop[0]

	if ally == null or enemy == null:
		_fail("Battle harness has no ally or enemy for the side-aware test")
		return

	var home := Vector2(-100, -40)
	var ally_context := _position_context(ally, enemy, home)
	var enemy_context := _position_context(enemy, ally, home)

	var ally_walk := _move_target(walk, ally_context, ally)
	var enemy_walk := _move_target(walk, enemy_context, enemy)
	var ally_teleport := _move_target(teleports[0], ally_context, ally)
	var enemy_teleport := _move_target(teleports[0], enemy_context, enemy)
	var ally_return := _move_target(teleports[1], ally_context, ally)
	var enemy_return := _move_target(teleports[1], enemy_context, enemy)

	print(
		"BATTLE_TEST_SIDE_AWARE walk=", ally_walk.x, "/", enemy_walk.x,
		" teleport=", ally_teleport.x, "/", enemy_teleport.x,
		" return=", ally_return.x, "/", enemy_return.x
	)

	if not is_equal_approx(ally_walk.x, 30.0) or not is_equal_approx(enemy_walk.x, -30.0):
		_fail("Warp Attack opening move is not mirrored for the caster's side")

	if not is_equal_approx(ally_teleport.x, enemy.node.position.x - 30.0):
		_fail("Warp Attack teleport is not mirrored for an ally caster")

	if not is_equal_approx(enemy_teleport.x, ally.node.position.x + 30.0):
		_fail("Warp Attack teleport is not mirrored for an enemy caster")

	if not is_equal_approx(ally_return.x, home.x - 50.0):
		_fail("Warp Attack return teleport is not mirrored for an ally caster")

	if not is_equal_approx(enemy_return.x, home.x + 50.0):
		_fail("Warp Attack return teleport is not mirrored for an enemy caster")

	var aoe: Ability = load("res://database/Abilities/Attacks/AOEAttack.tres")
	var aoe_walk: MoveStep = null
	var aoe_camera: PositionRef = null

	for step in aoe.action_sequence.walk():
		if step is MoveStep and step.mode == MoveStep.Mode.WALK and aoe_walk == null:
			aoe_walk = step
		elif step is CameraStep and step.position != null and aoe_camera == null:
			aoe_camera = step.position

	if aoe_walk == null or aoe_camera == null:
		_fail("AOE Attack is missing its walk or camera position")
		return

	var ally_aoe_walk := _move_target(aoe_walk, ally_context, ally)
	var enemy_aoe_walk := _move_target(aoe_walk, enemy_context, enemy)
	var ally_aoe_camera := aoe_camera.resolve(ally_context)
	var enemy_aoe_camera := aoe_camera.resolve(enemy_context)
	print(
		"BATTLE_TEST_SIDE_AWARE_AOE walk=", ally_aoe_walk.x, "/", enemy_aoe_walk.x,
		" camera=", ally_aoe_camera.x, "/", enemy_aoe_camera.x
	)

	if not is_equal_approx(ally_aoe_walk.x, -20.0) or not is_equal_approx(enemy_aoe_walk.x, 20.0):
		_fail("AOE Attack opening move is not mirrored for the caster's side")

	if not is_equal_approx(ally_aoe_camera.x, 20.0) or not is_equal_approx(enemy_aoe_camera.x, -20.0):
		_fail("AOE Attack camera position is not mirrored for the caster's side")


func _position_context(caster: Actor, target: Actor, home: Vector2) -> ActionSequenceContext:
	var context := ActionSequenceContext.new()
	context.battle = battle
	context.caster = caster
	context.target = target
	context.home_position = home
	return context


func _move_target(step: MoveStep, context: ActionSequenceContext, subject: Actor) -> Vector2:
	var offsetized := Vector2(context.battle.offsetize(step.offset.x, subject), step.offset.y)

	if step.destination == null:
		return subject.node.position + offsetized

	return step.destination.resolve(context, subject) + offsetized


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
	var first_before := first.health
	var second_before := second.health
	await battle.use_ability_now(Party.Leader, ability, first)
	print("BATTLE_TEST_ICY_DRIZZLE first=", first_before, "->", first.health, " second=", second_before, "->", second.health)

	if first.health >= first_before or second.health >= second_before:
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

	var first_before := first.health
	var second_before := second.health
	await battle.use_ability_now(Party.Leader, ability, first)
	var first_damage := first_before - first.health
	var second_damage := second_before - second.health
	print("BATTLE_TEST_TRAP first=", first_damage, " second=", second_damage, " pending=", battle.pending_traps.size())

	if first_damage <= 0 or second_damage <= first_damage:
		_fail("Trap did not interrupt only the hit target")

	if battle.pending_traps.size() != 1:
		_fail("Trap was not queued exactly once")

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Trap test left the turn locked")

	var caster := Party.Leader
	var caster_before := caster.health
	await battle.resolve_traps()
	print("BATTLE_TEST_TRAP_COUNTER caster=", caster_before, "->", caster.health)

	if caster.health >= caster_before:
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
	damage.miss_branch = true
	# The miss animation holds the turn until it finishes. Waiting for it here
	# keeps the check deterministic instead of racing the detached animation.
	var miss := MissStep.new()
	miss.wait = true
	damage.miss_steps = [miss]

	var sequence := ActionSequence.new()
	sequence.steps.append(damage)
	ability.action_sequence = sequence

	var before := target.health
	await battle.use_ability_now(Party.Leader, ability, target)
	print("BATTLE_TEST_MISS before=", before, " after=", target.health)

	if target.health != before:
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


func _test_state_pose() -> void:
	var caster := Party.Leader

	if caster == null or caster.node == null:
		_fail("Battle harness has no caster for the state pose test")
		return

	var original_frames := caster.node.sprite_frames
	caster.node.sprite_frames = load("res://art/BT/StoneGuardian/StoneGuardianBT.tres")

	var pose_state := State.new()
	pose_state.name = "BattleTestPose"
	pose_state.pose = "Guard"
	caster.states.append(pose_state)

	battle.anim("", caster)
	print("BATTLE_TEST_STATE_POSE animation=", caster.node.animation)

	if caster.node.animation != "Guard":
		_fail("A state pose did not replace the idle animation")

	caster.states.erase(pose_state)

	var sturdy: Ability = load("res://database/Abilities/SturdyGuard.tres")
	await battle.use_ability_now(caster, sturdy, caster)
	battle.anim("", caster)
	print("BATTLE_TEST_STATE_POSE_ABILITY animation=", caster.node.animation, " barrier=", caster.has_state("Barrier"))

	if not caster.has_state("Barrier"):
		_fail("Sturdy Guard did not apply Barrier")

	if caster.node.animation != "Guard":
		_fail("Sturdy Guard did not keep the Barrier pose")

	caster.remove_state("Barrier")
	caster.node.sprite_frames = original_frames
	caster.node.play("Idle")


func _test_enemy_preview_setup() -> void:
	var enemy_sequence := Battle.build_preview_sequence(1, "res://database/Enemies/Pterogon.tres")

	if enemy_sequence == null or enemy_sequence.Enemies.size() != 1:
		_fail("Enemy preview did not build a single-enemy sequence")
		return

	print("BATTLE_TEST_ENEMY_PREVIEW enemy=", enemy_sequence.Enemies[0].first_name)

	if enemy_sequence.Enemies[0].first_name != "Pterogon":
		_fail("Enemy preview did not use the chosen enemy")

	var dummy_sequence := Battle.build_preview_sequence(3, "")

	if dummy_sequence == null or dummy_sequence.Enemies.size() != 3:
		_fail("Preview target count did not build three dummies")


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
