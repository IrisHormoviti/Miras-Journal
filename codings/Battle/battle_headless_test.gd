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
const AlwaysConditionScript = preload("res://codings/Battle/Steps/Conditions/always_condition.gd")
const FlagConditionScript = preload("res://codings/Battle/Steps/Conditions/flag_condition.gd")
const HealthConditionScript = preload("res://codings/Battle/Steps/Conditions/health_condition.gd")
const NotConditionScript = preload("res://codings/Battle/Steps/Conditions/not_condition.gd")
const AllConditionScript = preload("res://codings/Battle/Steps/Conditions/all_condition.gd")
const AnyConditionScript = preload("res://codings/Battle/Steps/Conditions/any_condition.gd")
const TurnConditionScript = preload("res://codings/Battle/Steps/Conditions/turn_condition.gd")
const StateConditionScript = preload("res://codings/Battle/Steps/Conditions/state_condition.gd")
const HasActorConditionScript = preload("res://codings/Battle/Steps/Conditions/has_actor_condition.gd")
const ActorEqualsConditionScript = preload("res://codings/Battle/Steps/Conditions/actor_equals_condition.gd")
const HitOutcomeConditionScript = preload("res://codings/Battle/Steps/Conditions/hit_outcome_condition.gd")
const GroupSizeConditionScript = preload("res://codings/Battle/Steps/Conditions/group_size_condition.gd")
const GroupStateConditionScript = preload("res://codings/Battle/Steps/Conditions/group_state_condition.gd")
const SummonedAlliesConditionScript = preload("res://codings/Battle/Steps/Conditions/summoned_allies_condition.gd")

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
	_test_migrated_sequences_load()
	_test_migrated_sequence_wiring()
	await _test_stone_guardian_adapt()
	await _test_asteria_followup()
	await _test_new_step_modes()
	await _test_battle_event_sequence()
	await _test_conditions()

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

	if branch.condition == null or branch.condition.get_script() != HitOutcomeConditionScript:
		_fail("A new branch was not preset with a hit outcome condition")

	# A fresh branch comes preset with a hit-outcome condition that matches
	# every roll, so it can be narrowed down from there.
	for outcome in [HitOutcome.HIT, HitOutcome.CRIT, HitOutcome.MISS]:
		ctx.roll = outcome

		if not branch._matches(ctx):
			_fail("Default branch did not match every hit outcome")

	var hit := HitOutcomeConditionScript.new()
	hit.outcomes = 3
	branch.condition = hit
	ctx.roll = HitOutcome.HIT

	if not branch._matches(ctx):
		_fail("Hit condition did not match a hit")

	ctx.roll = HitOutcome.CRIT

	if not branch._matches(ctx):
		_fail("Hit condition did not match a crit")

	ctx.roll = HitOutcome.MISS

	if branch._matches(ctx):
		_fail("Hit condition matched a miss")

	var miss := HitOutcomeConditionScript.new()
	miss.outcomes = 4
	branch.condition = miss
	ctx.roll = HitOutcome.CRIT

	if branch._matches(ctx):
		_fail("Miss condition matched a crit")

	ctx.roll = HitOutcome.MISS

	if not branch._matches(ctx):
		_fail("Miss condition did not match a miss")

	print("BATTLE_TEST_BRANCH_OUTCOMES ok")


const MIGRATED_SEQUENCES := [
	"FirstBattleEntrance.tres",
	"FirstBattleJumpSucc.tres",
	"FirstBattleAura1.tres",
	"FirstBattleAura2.tres",
	"FirstBattleAura3.tres",
	"FirstBattleVictory.tres",
	"AlcineFollow1Victory.tres",
	"AlcineFollow2Entrance.tres",
	"AlcineFollow3.tres",
	"ArenaGameOver.tres",
	"StoneGuardianEntrance.tres",
	"StoneGuardianLoop.tres",
	"StoneGuardianAdapt.tres",
	"StoneGuardianVictory.tres",
	"AsteriaBossSummon.tres",
	"AsteriaBossPhase.tres",
	"AsteriaBossFollowup.tres",
	"Nov2MiraDream.tres",
]

const MIGRATED_BATTLE_SEQUENCES := [
	"res://database/BattleSeq/FirstBattle.tres",
	"res://database/BattleSeq/AlcineFollow1.tres",
	"res://database/BattleSeq/AlcineFollow2.tres",
	"res://database/BattleSeq/AsteriaBoss.tres",
	"res://database/BattleSeq/ColorTutorial.tres",
	"res://database/BattleSeq/LazuliteHeartBoss.tres",
	"res://database/BattleSeq/StoneGuardianBoss.tres",
	"res://database/BattleSeq/ArenaBattles/Round1.tres",
	"res://database/BattleSeq/ArenaBattles/Round2.tres",
	"res://database/BattleSeq/ArenaBattles/Round3.tres",
	"res://database/BattleSeq/ArenaBattles/Round4.tres",
	"res://database/BattleSeq/ArenaBattles/Round5.tres",
	"res://database/BattleSeq/ArenaBattles/Round6.tres",
]


func _test_migrated_sequences_load() -> void:
	for file in MIGRATED_SEQUENCES:
		var path: String = "res://database/Sequences/Action/" + str(file)
		var sequence := load(path) as ActionSequence

		if sequence == null:
			_fail("Could not load migrated sequence " + file)
			continue

		if sequence.steps.is_empty():
			_fail("Migrated sequence is empty: " + file)
			continue

		var walked := sequence.walk()

		for step in walked:
			if step == null:
				_fail("Migrated sequence has a null step: " + file)
				break

		print("BATTLE_TEST_SEQUENCE ", file, " steps=", walked.size())


func _test_migrated_sequence_wiring() -> void:
	for path in MIGRATED_BATTLE_SEQUENCES:
		var sequence := load(path) as BattleSequence

		if sequence == null:
			_fail("Could not load battle sequence " + path)
			continue

		if sequence.EntranceSequence != "" or sequence.VictorySequence != "" or sequence.DefeatSequence != "":
			_fail("Battle sequence still uses a legacy named sequence: " + path)

		for event in sequence.Events:
			if event == null:
				continue

			if event.result == BattleEvent.RES.CALL_FUNCTION:
				_fail("Battle event still calls a legacy function: " + path + " " + event.parameter1)

			if event.result == BattleEvent.RES.SEQUENCE and event.sequence == null:
				_fail("Battle event has no sequence: " + path)

		print("BATTLE_TEST_WIRING ", path.get_file())

	if (load("res://database/BattleSeq/FirstBattle.tres") as BattleSequence).entrance_sequence == null:
		_fail("First battle has no entrance sequence")

	if (load("res://database/BattleSeq/StoneGuardianBoss.tres") as BattleSequence).victory_sequence == null:
		_fail("Stone Guardian has no victory sequence")

	if (load("res://database/BattleSeq/ArenaBattles/Round1.tres") as BattleSequence).defeat_sequence == null:
		_fail("Arena round has no defeat sequence")

	var first_battle := load("res://database/BattleSeq/FirstBattle.tres") as BattleSequence

	for event in first_battle.Events:
		if event.result == BattleEvent.RES.FORCE_MOVE and event.resource is Ability:
			if (event.resource as Ability).name == "JumpSucc" and (event.resource as Ability).action_sequence == null:
				_fail("The scripted JumpSucc ability was not migrated to a sequence")


func _test_stone_guardian_adapt() -> void:
	var guardian_data: Actor = load("res://database/Enemies/StoneGuardian.tres").duplicate()
	var guardian := await battle.add_to_troop(guardian_data)

	if guardian == null:
		_fail("Could not add the Stone Guardian for the sequence test")
		return

	var alcine := Party.Member1

	if alcine == null:
		_fail("The Stone Guardian sequence test needs Alcine in the party")
		return

	var drill: Ability = load("res://database/Abilities/Drill.tres")
	var sequence := load("res://database/Sequences/Action/StoneGuardianAdapt.tres") as ActionSequence
	var previous_current := battle.CurrentChar
	var previous_turn_ind := battle.TurnInd
	var previous_color := guardian.main_color

	guardian.attack_multiplier = 1
	guardian.magic_multiplier = 1
	guardian.next_move = null
	guardian.next_target = null
	Event.remove_flag(&"Event/StoneGuardianFinisher")

	await battle.run_battle_sequence(sequence, alcine, null, false)

	print(
		"BATTLE_TEST_GUARDIAN_ADAPT atk=", guardian.attack_multiplier,
		" mag=", guardian.magic_multiplier,
		" next=", guardian.next_move.name if guardian.next_move != null else "<none>",
		" target=", guardian.next_target.first_name if guardian.next_target != null else "<none>",
		" flag=", Event.check_flag(&"Event/StoneGuardianFinisher")
	)

	if not is_equal_approx(guardian.attack_multiplier, 2.0):
		_fail("Stone Guardian sequence did not double the attack multiplier")

	if not is_equal_approx(guardian.magic_multiplier, 2.0):
		_fail("Stone Guardian sequence did not double the magic multiplier")

	if guardian.next_move != drill:
		_fail("Stone Guardian sequence did not queue Drill")

	if guardian.next_target != alcine:
		_fail("Stone Guardian sequence did not target Alcine")

	if not Event.check_flag(&"Event/StoneGuardianFinisher"):
		_fail("Stone Guardian sequence did not set the finisher flag")

	if battle.CurrentChar != guardian:
		_fail("Stone Guardian sequence did not make the Guardian current")

	if battle.TurnInd != battle.TurnOrder.find(guardian) - 1:
		_fail("Stone Guardian sequence did not force the Guardian's turn")

	# Put the harness back the way it was.
	battle.CurrentChar = previous_current
	battle.act.CurrentChar = previous_current
	battle.TurnInd = previous_turn_ind
	guardian.main_color = previous_color
	Event.remove_flag(&"Event/StoneGuardianFinisher")


func _test_new_step_modes() -> void:
	var caster := Party.Leader

	if caster == null:
		_fail("New step mode test needs a caster")
		return

	var hold := BattleControlStep.new()
	hold.mode = BattleControlStep.Mode.HOLD_TURN
	await hold.run(_test_context(caster))

	if not battle.lock_turn or battle.lock_count != 1:
		_fail("Hold turn step did not lock the turn")

	var release := BattleControlStep.new()
	release.mode = BattleControlStep.Mode.RELEASE_TURN
	await release.run(_test_context(caster))

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Release turn step did not unlock the turn")

	var previous_current := battle.CurrentChar
	var previous_act: Actor = battle.act.CurrentChar
	var set_current := BattleFlowStep.new()
	set_current.mode = BattleFlowStep.Mode.SET_CURRENT
	set_current.actor = ActorRef.new(ActorRef.Mode.CASTER)
	await set_current.run(_test_context(battle.Troop[0]))

	if battle.CurrentChar != battle.Troop[0]:
		_fail("Set current step did not change the battle's current actor")

	battle.CurrentChar = previous_current
	battle.act.CurrentChar = previous_act

	var await_animation := ActorSpriteStep.new()
	await_animation.mode = ActorSpriteStep.Mode.AWAIT_ANIMATION
	await_animation.actor = ActorRef.new(ActorRef.Mode.CASTER)
	await await_animation.run(_test_context(caster))

	print("BATTLE_TEST_NEW_STEP_MODES ok")


func _test_context(caster: Actor) -> ActionSequenceContext:
	var ctx := ActionSequenceContext.new()
	ctx.battle = battle
	ctx.runner = battle.action_runner
	ctx.caster = caster
	ctx.target = battle.Troop[0] if not battle.Troop.is_empty() else caster
	ctx.home_position = battle.initial
	return ctx


func _test_battle_event_sequence() -> void:
	var flag := &"BattleTestEventSequence"
	var event := BattleEvent.new()
	event.result = BattleEvent.RES.SEQUENCE
	event.hold_turn = true
	event.sequence_caster = &"Mira"

	var sequence := ActionSequence.new()
	var wait := WaitStep.new()
	wait.duration = 0.01
	sequence.steps.append(wait)

	var set_flag := EventStep.new()
	set_flag.mode = EventStep.Mode.FLAG_SET
	set_flag.flag = flag
	set_flag.value = 1
	sequence.steps.append(set_flag)

	event.sequence = sequence
	Event.remove_flag(flag)
	await event.run()

	print("BATTLE_TEST_EVENT_SEQUENCE flag=", Event.check_flag(flag))

	if not Event.check_flag(flag):
		_fail("Battle event did not run its sequence")

	Event.remove_flag(flag)


func _test_asteria_followup() -> void:
	var asteria_resource: Actor = load("res://database/Enemies/AsteriaEnemy.tres")

	if asteria_resource.followup_ability == null or asteria_resource.followup_ability.action_sequence == null:
		_fail("Asteria's follow-up ability was not migrated to a sequence")

	var asteria_data: Actor = asteria_resource.duplicate()
	var asteria := await battle.add_to_troop(asteria_data)

	if asteria == null:
		_fail("Could not add Asteria for the follow-up sequence test")
		return

	# The preview party also contains Asteria, and get_actor() prefers the
	# party copy, so move the party one aside for this codename lookup.
	var party_asteria := Party.get_member(&"Asteria")
	var saved_codename: StringName = party_asteria.codename if party_asteria != null else &""

	if party_asteria != null:
		party_asteria.codename = &"AsteriaPartyTest"

	var sequence := load("res://database/Sequences/Action/AsteriaBossFollowup.tres") as ActionSequence

	# The late phase branch only heals Asteria, so it can be checked exactly.
	Event.add_flag(&"Event/AsteriaBoss", 4)
	asteria.health = 50
	asteria.max_hp = 130

	await battle.run_battle_sequence(sequence, asteria, null, false)

	print("BATTLE_TEST_ASTERIA_FOLLOWUP health=", asteria.health)

	if party_asteria != null:
		party_asteria.codename = saved_codename

	if asteria.health != 65:
		_fail("Asteria follow-up sequence did not heal her for 15")

	Event.remove_flag(&"Event/AsteriaBoss")


func _test_conditions() -> void:
	var ctx := _test_context(Party.Leader)
	var mira := Party.Leader
	var target := battle.Troop[0]

	var always = AlwaysConditionScript.new()

	if not always.check(ctx):
		_fail("Always condition did not pass")

	Event.add_flag(&"BattleTestCondition", 2)
	var flag = FlagConditionScript.new()
	flag.expression = &"BattleTestCondition >= 2"

	if not flag.check(ctx):
		_fail("Flag condition did not evaluate its Event.f expression")

	flag.expression = &"BattleTestCondition < 2"

	if flag.check(ctx):
		_fail("Flag condition ignored its Event.f expression")

	Event.remove_flag(&"BattleTestCondition")

	var health = HealthConditionScript.new()
	health.actor = ActorRef.new(ActorRef.Mode.CASTER)
	health.comparator = BattleCondition.Comparator.GT
	health.value = 0

	if not health.check(ctx):
		_fail("Health condition did not pass for a living caster")

	var negated = NotConditionScript.new()
	negated.condition = health

	if negated.check(ctx):
		_fail("Not condition did not invert its child")

	var all = AllConditionScript.new()
	all.conditions.append(health)
	all.conditions.append(negated)

	if all.check(ctx):
		_fail("All condition passed with a false child")

	var any = AnyConditionScript.new()
	any.conditions.append(negated)
	any.conditions.append(health)

	if not any.check(ctx):
		_fail("Any condition did not pass with a true child")

	var turn = TurnConditionScript.new()
	turn.turn_min = 0
	turn.turn_max = 999

	if not turn.check(ctx):
		_fail("Turn condition did not match a valid turn range")

	var state = StateConditionScript.new()
	state.actor = ActorRef.new(ActorRef.Mode.CASTER)
	state.state = &"KnockedOut"
	state.present = false

	if not state.check(ctx):
		_fail("State condition did not pass for a missing state")

	var has_actor = HasActorConditionScript.new()
	has_actor.codename = mira.codename

	if not has_actor.check(ctx):
		_fail("Has actor condition did not find the party leader")

	var equals = ActorEqualsConditionScript.new()
	equals.actor = ActorRef.new(ActorRef.Mode.CASTER)
	equals.other = ActorRef.new(ActorRef.Mode.CASTER)

	if not equals.check(ctx):
		_fail("Actor equals condition did not match the same caster")

	var hit = HitOutcomeConditionScript.new()
	hit.outcomes = 1
	ctx.roll = HitOutcome.HIT

	if not hit.check(ctx):
		_fail("Hit outcome condition did not match a hit")

	hit.outcomes = 2

	if hit.check(ctx):
		_fail("Hit outcome condition matched the wrong outcome")

	var group_size = GroupSizeConditionScript.new()
	group_size.group = ActorGroup.Kind.TROOP
	group_size.comparator = BattleCondition.Comparator.GE
	group_size.value = 1

	if not group_size.check(ctx):
		_fail("Group size condition did not count the troop")

	var group_state = GroupStateConditionScript.new()
	group_state.group = ActorGroup.Kind.TROOP
	group_state.state = &"KnockedOut"
	group_state.present = false
	group_state.group_match = GroupStateConditionScript.GroupMatch.ANY

	if not group_state.check(ctx):
		_fail("Group state condition did not pass for a troop without knocked out actors")

	var summons = SummonedAlliesConditionScript.new()
	summons.actor = ActorRef.new(ActorRef.Mode.CASTER)
	summons.empty = false

	if not summons.check(ctx):
		_fail("Summoned allies condition did not pass for a populated summon list")

	if target == null:
		_fail("Condition test lost its target")
		return

	print("BATTLE_TEST_CONDITIONS ok")
