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
const StatConditionScript = preload("res://codings/Battle/Steps/Conditions/stat_condition.gd")
const NotConditionScript = preload("res://codings/Battle/Steps/Conditions/not_condition.gd")
const AllConditionScript = preload("res://codings/Battle/Steps/Conditions/all_condition.gd")
const AnyConditionScript = preload("res://codings/Battle/Steps/Conditions/any_condition.gd")
const TurnConditionScript = preload("res://codings/Battle/Steps/Conditions/turn_condition.gd")
const ActorTurnConditionScript = preload("res://codings/Battle/Steps/Conditions/actor_turn_condition.gd")
const StateConditionScript = preload("res://codings/Battle/Steps/Conditions/state_condition.gd")
const HasActorConditionScript = preload("res://codings/Battle/Steps/Conditions/has_actor_condition.gd")
const ActorEqualsConditionScript = preload("res://codings/Battle/Steps/Conditions/actor_equals_condition.gd")
const HitOutcomeConditionScript = preload("res://codings/Battle/Steps/Conditions/hit_outcome_condition.gd")
const GroupSizeConditionScript = preload("res://codings/Battle/Steps/Conditions/group_size_condition.gd")
const GroupStateConditionScript = preload("res://codings/Battle/Steps/Conditions/group_state_condition.gd")
const CollectionConditionScript = preload("res://codings/Battle/Steps/Conditions/collection_condition.gd")

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
		await _finish(1)
		return

	battle = BATTLE_SCENE.instantiate()
	add_child(battle)

	await get_tree().create_timer(3.0).timeout

	if not is_instance_valid(battle) or battle.Troop.is_empty():
		_fail("Battle harness failed to start")
		await _finish(1)
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
	await _test_action_windup()
	await _test_auto_idle()
	await _test_state_pose()
	await _test_state_sequences()
	await _test_migrated_state_turns()
	await _test_state_identity_and_cleanup()
	await _test_enemy_revive()
	_test_enemy_preview_setup()
	_test_branch_outcomes()
	_test_migrated_sequences_load()
	_test_migrated_sequence_wiring()
	await _test_last_sequences()
	await _test_stone_guardian_pattern()
	await _test_aura_break_followup()
	await _test_self_target_ai_move()
	await _test_asteria_followup()
	await _test_new_step_modes()
	await _test_battle_event_sequence()
	await _test_battle_events_run_in_order()
	await _test_battle_event_conditions()
	await _test_conditions()

	print("BATTLE_TEST_DONE failed=", failed)
	await _finish(1 if failed else 0)


## Frees the battle and lets the tree settle before quitting, so the headless
## run does not report leaked objects and RIDs at exit.
func _finish(code: int) -> void:
	if is_instance_valid(battle):
		battle.free()

	battle = null
	Battle.current = null
	Battle.sequence = null
	Battle.headless_driver = false

	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(code)


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

	var each: ForEachActorStep = null

	for step in ability.action_sequence.walk():
		if step is ForEachActorStep:
			each = step
			break

	if each == null or not is_equal_approx(each.stagger, 0.3):
		_fail("Icy Drizzle lost its AOE stagger")

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
	ability.success_chance = 1

	var each := ForEachActorStep.new()
	each.group = ActorGroup.Kind.ENEMIES
	each.exclude_caster = true
	each.wait = false

	for i in 2:
		each.steps.append(_damage_step(TEST_DAMAGE))

	var sequence := ActionSequence.new()
	sequence.steps.append(each)
	ability.action_sequence = sequence
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


## A forced action can request the same wind-up as the battle UI (for example
## MAGIC casting) before its ability sequence starts.
func _test_action_windup() -> void:
	var caster := Party.Leader
	var target := battle.Troop[0]

	if caster == null or caster.node == null or target == null:
		_fail("Battle harness has no caster for the action wind-up test")
		return

	# A hit reaction from an earlier test can still be running and would reset the
	# caster to Idle while the wind-up plays. Let it finish first.
	await get_tree().create_timer(0.5).timeout

	var ability := Ability.nothing().duplicate() as Ability
	ability.name = "BattleTestMagicWindup"
	ability.callout = false

	var capture := AnimationCaptureStep.new()
	var sequence := ActionSequence.new()
	sequence.steps.append(capture)
	ability.action_sequence = sequence

	caster.node.play(&"Idle")

	await battle.use_ability_now(caster, ability, target, false, Actor.BtAction.MAGIC)
	print("BATTLE_TEST_ACTION_WINDUP played=", capture.played, " animation=", capture.animation)

	if not capture.played or capture.animation != &"Ability":
		_fail("MAGIC wind-up did not play the ability animation")

	battle.anim("", caster)
	battle.Action = false


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

	await caster.remove_state("Barrier")
	caster.node.sprite_frames = original_frames
	caster.node.play("Idle")


func _test_state_sequences() -> void:
	if battle.Troop.size() < 2:
		_fail("Battle harness needs two enemies for the state sequence test")
		return

	var target := battle.Troop[1]
	target.dont_idle = false
	target.controllable = true

	var on_add := ActorFlagStep.new()
	on_add.mode = ActorFlagStep.Mode.DONT_IDLE
	on_add.actor = ActorRef.new(ActorRef.Mode.TARGET)
	on_add.enabled = true

	var on_remove := ActorFlagStep.new()
	on_remove.mode = ActorFlagStep.Mode.DONT_IDLE
	on_remove.actor = ActorRef.new(ActorRef.Mode.TARGET)
	on_remove.enabled = false

	var on_turn := ActorFlagStep.new()
	on_turn.mode = ActorFlagStep.Mode.CONTROLLABLE
	on_turn.actor = ActorRef.new(ActorRef.Mode.TARGET)
	on_turn.enabled = false

	var hook_state := State.new()
	hook_state.name = "BattleTestStateHooks"
	hook_state.turns = -1
	hook_state.on_add = _hook_sequence(on_add)
	hook_state.on_remove = _hook_sequence(on_remove)
	hook_state.on_turn = _hook_sequence(on_turn)

	await target.add_state(hook_state, -1, Party.Leader, true, true)
	print("BATTLE_TEST_STATE_ADD dont_idle=", target.dont_idle)

	if not target.dont_idle:
		_fail("A state's on-add sequence did not run")

	await battle.run_state_sequence(hook_state.on_turn, hook_state, target)
	print("BATTLE_TEST_STATE_TURN controllable=", target.controllable)

	if target.controllable:
		_fail("A state's on-turn sequence did not run")

	await target.remove_state(hook_state, null, true)
	print("BATTLE_TEST_STATE_REMOVE dont_idle=", target.dont_idle)

	if target.dont_idle:
		_fail("A state's on-remove sequence did not run")

	target.controllable = true

	var burned: State = load("res://database/States/Burned.tres")
	var knocked_out: State = load("res://database/States/KnockedOut.tres")

	if burned.on_turn == null or knocked_out.on_turn == null or knocked_out.on_remove == null:
		_fail("Migrated state resources lost their sequences")


func _hook_sequence(step: BattleStep) -> ActionSequence:
	var sequence := ActionSequence.new()
	var steps: Array[BattleStep] = [step]
	sequence.steps = steps
	return sequence


func _test_migrated_state_turns() -> void:
	if battle.Troop.size() < 2:
		_fail("Battle harness needs two enemies for the migrated state test")
		return

	var target := battle.Troop[1]
	await battle.clear_states(target)

	target.next_target = null
	await target.add_state(load("res://database/States/Aggro.tres"), -1, Party.Leader, false, true)

	if target.next_target != Party.Leader:
		_fail("Aggro's on-add sequence did not point at its inflicter")

	await target.remove_state("Aggro", null, true)

	target.attack_multiplier = 1
	await battle.stat_change(&"Atk", 0.5, target, 3)

	if not target.has_state("AtkUp") or not is_equal_approx(target.attack_multiplier, 1.5):
		_fail("Stat buffs did not apply through add_state")

	await target.remove_state("AtkUp", null, true)

	if not is_equal_approx(target.attack_multiplier, 1.0):
		_fail("A stat buff's on-remove sequence did not restore its multiplier")

	target.set_health(target.max_hp)
	var burned: State = load("res://database/States/Burned.tres")
	await target.add_state(burned, -1, Party.Leader, false, true)
	var burned_state := target.get_state("Burned")
	var before := target.health
	await battle.run_state_sequence(burned_state.on_turn, burned_state, target)
	print("BATTLE_TEST_STATE_BURNED health=", before, "->", target.health)

	if target.health >= before:
		_fail("Burned's on-turn sequence did not deal damage")

	await target.add_state(load("res://database/States/AuraBreak.tres"), -1, Party.Leader, false, true)
	target.set_aura(5)
	var aura_break := target.get_state("Aura Break")
	await battle.run_state_sequence(aura_break.on_turn, aura_break, target)

	if target.has_state("Aura Break"):
		_fail("AuraBreak did not clear once the actor had aura")

	target.set_health(0)
	target.set_aura(0)
	target.next_move = null
	await target.add_state(load("res://database/States/KnockedOut.tres"), -1, Party.Leader, false, true)
	var knocked_out := target.get_state("Knocked Out")
	await battle.run_state_sequence(knocked_out.on_turn, knocked_out, target)

	if target.next_move != Ability.nothing():
		_fail("KnockedOut did not skip a downed actor's turn")

	await target.remove_state(knocked_out, null, true)
	print("BATTLE_TEST_STATE_RECOVER health=", target.health, " aura=", target.aura)

	if target.health != 10 or target.aura != target.max_aura:
		_fail("KnockedOut's on-remove sequence did not recover the actor")

	target.set_health(target.max_hp)
	await battle.clear_states(target)


func _test_state_identity_and_cleanup() -> void:
	var target := battle.Troop[0]

	if target == null:
		_fail("Battle harness has no target for the state identity test")
		return

	await battle.clear_states(target)

	var aura_break: State = load("res://database/States/AuraBreak.tres")
	var added: State = await target.add_state(aura_break, -1, Party.Leader, false, true)
	print("BATTLE_TEST_STATE_IDENTITY aura_break=", added.filename, " by_file=", target.has_state("AuraBreak"))

	if added.filename != "AuraBreak" or not target.has_state("AuraBreak"):
		_fail("A resource-added state lost its canonical filename")

	var unbreaking: State = load("res://database/States/UnbreakingAura.tres")
	added = await target.add_state(unbreaking, -1, Party.Leader, false, true)

	if added.filename != "UnbreakingAura" or not target.has_state("UnbreakingAura"):
		_fail("UnbreakingAura lost its canonical filename")

	var guarding: State = load("res://database/States/Guarding.tres")
	added = await target.add_state(guarding, -1, Party.Leader, false, true)

	if not is_equal_approx(added.aura_on_damage, 1.0):
		_fail("Guarding did not load its aura-on-damage value")

	await target.add_state("Burned", -1, target, false, true)
	await target.add_state("Zapped", -1, target, false, true)
	battle.reset_all()
	print("BATTLE_TEST_STATE_CLEANUP remaining=", target.states.size())

	if not target.states.is_empty():
		_fail("reset_all left states on the actor")


func _test_enemy_revive() -> void:
	var target := battle.Troop[0]

	if target == null:
		_fail("Battle harness has no target for the enemy revive test")
		return

	var previous := battle.CurrentChar
	await battle.clear_states(target)
	target.set_health(0)
	target.set_aura(0)
	target.next_move = null
	target.next_action = Actor.BtAction.UNSET
	battle.CurrentChar = target
	await target.add_state("KnockedOut", -1, Party.Leader, false, true)
	await battle.handle_states()

	if target.next_move != Ability.nothing():
		_fail("A downed enemy did not skip its turn")

	target.set_health(target.max_hp)
	target.next_move = null
	target.next_action = Actor.BtAction.UNSET
	await battle.handle_states()
	print("BATTLE_TEST_ENEMY_REVIVE health=", target.health, " knocked_out=", target.has_state("KnockedOut"))

	if target.has_state("KnockedOut") or target.health <= 0:
		_fail("A healed enemy could not revive on its turn")

	target.set_health(target.max_hp)
	await battle.clear_states(target)
	battle.CurrentChar = previous


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
	"ArenaGameOver.tres",
	"StoneGuardianFinisher.tres",
	"StoneGuardianTurn.tres",
	"AsteriaBossSummon.tres",
	"AsteriaBossPhase.tres",
	"AsteriaBossFollowup.tres",
	"Nov2MiraDream.tres",
	"RedShift.tres",
	"ActiveSupport.tres",
	"PhoenixDive.tres",
	"Pterogon_death.tres",
]

const MIGRATED_BATTLE_SEQUENCES := [
	"res://database/BattleSeq/FirstBattle.tres",
	"res://database/BattleSeq/AlcineFollow.tres",
	"res://database/BattleSeq/AsteriaBoss.tres",
	"res://database/BattleSeq/ColorTutorial.tres",
	"res://database/BattleSeq/LazuliteHeartBoss.tres",
	"res://database/BattleSeq/SkritcherRootDaze.tres",
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

		for event in sequence.Events:
			if event == null:
				continue

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
		if event.result == BattleEvent.RES.FORCE_MOVE and event.move is Ability:
			if (event.move as Ability).name == "JumpSucc" and (event.move as Ability).action_sequence == null:
				_fail("The scripted JumpSucc ability was not migrated to a sequence")

			if (event.move as Ability).name == "JumpSucc" and event.move_action != BattleEvent.MoveAction.ACT:
				_fail("The scripted JumpSucc event lost its attack action")

	var color_tutorial := load("res://database/BattleSeq/ColorTutorial.tres") as BattleSequence
	var dialog_event := color_tutorial.Events[0] if not color_tutorial.Events.is_empty() else null

	if (
		dialog_event == null
		or dialog_event.dialog_file != "story_0"
		or dialog_event.dialog_cue != "color_tutorial_aurabreak"
	):
		_fail("The color tutorial event lost its dialog fields")
	elif not dialog_event.hold_turn:
		_fail("The color tutorial dialog event stopped holding the turn")


func _test_last_sequences() -> void:
	var caster := Party.Leader
	var target := battle.Troop[0] if not battle.Troop.is_empty() else null

	if caster == null or target == null:
		_fail("Last sequence test needs a caster and target")
		return

	# Red-Shift scales with the number of states on its target.
	var red_shift := load("res://database/Abilities/RedShift.tres") as Ability
	var red_damage: DamageStep = red_shift.primary_damage_step() if red_shift != null else null

	if red_damage == null or red_damage.power == null:
		_fail("Red-Shift has no damage step")
	else:
		var ctx := _test_context(caster)
		ctx.ability = red_shift
		ctx.target = target
		var expected := 8 * (target.states.size() + 1)
		var actual := int(round(red_damage.power.resolve(ctx)))
		print("BATTLE_TEST_REDSHIFT states=", target.states.size(), " damage=", actual)

		if actual != expected:
			_fail("Red-Shift damage did not scale with the target's states")

	# Active Support doubles the magic of every other living ally for a turn.
	var support := load("res://database/Abilities/ActiveSupport.tres") as Ability

	if support == null or support.action_sequence == null:
		_fail("Active Support has no sequence")
	else:
		var before: Dictionary = {}

		for actor in Party.current:
			if actor != null and actor.health > 0:
				before[actor] = actor.magic_multiplier

		await battle.action_runner.run_ability(support, caster, caster, false)

		for actor: Actor in before:
			if actor == caster:
				continue

			if not is_equal_approx(actor.magic_multiplier, float(before[actor]) + 1.0):
				_fail("Active Support did not double an ally's magic")

			if not actor.has_state("MagUp"):
				_fail("Active Support did not apply MagicUp")

		for actor: Actor in before:
			actor.magic_multiplier = float(before[actor])
			actor.remove_state("MagUp")

	# Phoenix Dive damages every enemy, then revives fallen allies.
	var phoenix := load("res://database/Abilities/Followups/PhoenixDive.tres") as Ability
	var knocked_out: State = load("res://database/States/KnockedOut.tres")
	var revive_loop: ForEachActorStep = null
	var has_enemy_loop := false

	if phoenix == null or phoenix.action_sequence == null:
		_fail("Phoenix Dive has no sequence")
	else:
		for step in phoenix.action_sequence.walk():
			if step is not ForEachActorStep:
				continue

			var loop := step as ForEachActorStep

			if loop.group == ActorGroup.Kind.ENEMIES:
				has_enemy_loop = true
			elif loop.group == ActorGroup.Kind.ALLIES and loop.include_dead:
				revive_loop = loop

		if not has_enemy_loop:
			_fail("Phoenix Dive no longer hits every enemy")

		if revive_loop == null:
			_fail("Phoenix Dive no longer revives fallen allies")
		else:
			var ally := Party.Member1
			var saved_health := ally.health if ally != null else 0
			var saved_aura := ally.aura if ally != null else 0

			if ally != null:
				ally.set_health(0)
				await ally.add_state(knocked_out, -1, caster, false, false)
				var ctx := _test_context(caster)
				ctx.target = caster
				await revive_loop.run(ctx)

				print(
					"BATTLE_TEST_PHOENIX_REVIVE health=", ally.health,
					" knocked_out=", ally.has_state("KnockedOut")
				)

				if ally.has_state("KnockedOut") or ally.health <= 0:
					_fail("Phoenix Dive did not revive a fallen ally")

				ally.set_health(saved_health)
				ally.set_aura(saved_aura)
				ally.remove_state("KnockedOut")

	# The Pterogon's retreat is authored data and is found from its codename.
	var death_sequence := load("res://database/Sequences/Action/Pterogon_death.tres") as ActionSequence
	var pterogon := load("res://database/Enemies/Pterogon.tres") as Actor
	var has_death_step := false

	if death_sequence != null:
		for step in death_sequence.walk():
			if step is BattleControlStep and (step as BattleControlStep).mode == BattleControlStep.Mode.DEATH:
				has_death_step = true

	if pterogon == null or battle.death_sequence_for(pterogon) != death_sequence:
		_fail("Pterogon does not resolve its codename-based death sequence")

	if not has_death_step:
		_fail("Pterogon_death does not finish the defeat")

	print("BATTLE_TEST_LAST_SEQUENCES ok")


func _test_stone_guardian_pattern() -> void:
	var boss := load("res://database/BattleSeq/StoneGuardianBoss.tres") as BattleSequence
	var finisher := load("res://database/Sequences/Action/StoneGuardianFinisher.tres") as ActionSequence
	var turn := load("res://database/Sequences/Action/StoneGuardianTurn.tres") as ActionSequence
	var adaptation := load("res://database/Abilities/Adaptation.tres") as Ability
	var guardian_data: Actor = load("res://database/Enemies/StoneGuardian.tres")

	if boss.Events.size() != 2:
		_fail("Stone Guardian battle events changed unexpectedly")

	var low_health: BattleEvent = null

	for event in boss.Events:
		if event != null and event.dialog_cue == "stone_guardian_still_standing":
			low_health = event

	if (
		low_health == null
		or low_health.dialog_file != "story_0"
	):
		_fail("Stone Guardian lost its below-200 dialogue event")

	if boss.victory_sequence != finisher:
		_fail("Stone Guardian victory does not use the finisher cutscene")

	var has_victory := false

	if finisher != null:
		for step in finisher.walk():
			if step is BattleControlStep and step.mode == BattleControlStep.Mode.VICTORY:
				has_victory = true

				if step.canvas_layer <= 2:
					_fail("Stone Guardian victory screen is not above the black fade")

	if not has_victory:
		_fail("Stone Guardian finisher never shows the victory screen")

	if turn == null or turn.steps.is_empty():
		_fail("Stone Guardian has no turn sequence")

	if guardian_data.turn_sequence != turn:
		_fail("Stone Guardian does not point at its turn sequence")

	var gather := load("res://database/Abilities/Gather.tres") as Ability

	if gather == null or not gather in guardian_data.abilities:
		_fail("Stone Guardian cannot use Gather when its AP runs out")

	if gather != null and not gather.recover_aura:
		_fail("Gather is not valued as AP recovery")

	if turn != null and not turn.steps.is_empty() and not turn.steps[0] is BranchStep:
		_fail("Stone Guardian turn does not start with its pattern branch")
	elif turn != null and not turn.steps.is_empty():
		var follow_up_branch := turn.steps[0] as BranchStep
		var follow_up_condition := follow_up_branch.condition as FollowUpCondition

		if follow_up_condition == null:
			_fail("Stone Guardian turn does not check for a follow-up turn")
		else:
			battle.follow_up_turn = true

			if not follow_up_condition.check(_test_context(guardian_data)):
				_fail("Stone Guardian follow-up condition did not match a follow-up turn")

			battle.follow_up_turn = false

			if follow_up_condition.check(_test_context(guardian_data)):
				_fail("Stone Guardian follow-up condition matched a normal turn")

		if follow_up_branch.if_steps.size() != 1:
			_fail("Stone Guardian follow-up turn is not a single move")
		else:
			var phase_move := follow_up_branch.if_steps[0] as BranchStep

			if phase_move == null:
				_fail("Stone Guardian follow-up turn does not choose its target")
			else:
				for steps in [phase_move.if_steps, phase_move.else_steps]:
					if (
						steps.size() != 1
						or not steps[0] is TurnStep
						or (steps[0] as TurnStep).mode != TurnStep.Mode.AI_MOVE
					):
						_fail("Stone Guardian follow-up turn is not a single move")

				if not phase_move.if_steps.is_empty():
					var targeted_move := phase_move.if_steps[0] as TurnStep

					if (
						targeted_move == null
						or targeted_move.target == null
						or targeted_move.target.mode != ActorRef.Mode.PARTY_MEMBER
						or targeted_move.target.party_index != 1
					):
						_fail("Stone Guardian below its phase threshold does not target Alcine")

		var finisher_branch: BranchStep = null

		if not follow_up_branch.else_steps.is_empty():
			finisher_branch = follow_up_branch.else_steps[0] as BranchStep

		var finisher_condition: AllCondition = null

		if finisher_branch != null:
			finisher_condition = finisher_branch.condition as AllCondition

		var has_low_health := false
		var has_alcine_down := false

		if finisher_condition == null:
			_fail("Stone Guardian finisher branch has no combined condition")
		else:
			for condition in finisher_condition.conditions:
				if (
					condition is StatCondition
					and condition.stat == StatConditionScript.Stat.HEALTH
					and condition.comparator == BattleCondition.Comparator.LT
					and condition.value == 150
				):
					has_low_health = true

				if condition is ActorAliveCondition and not condition.alive:
					has_alcine_down = true

		if not has_low_health or not has_alcine_down:
			_fail("Stone Guardian finisher can play before Alcine is down and it is below its phase threshold")

		var adapt_branch := _find_branch_with_ability(turn.steps[0], "Adaptation")
		var adapt_condition: AllCondition = null

		if adapt_branch != null:
			adapt_condition = adapt_branch.condition as AllCondition

		var has_not_adapted := false
		var has_aura_for_adapt := false

		if adapt_condition != null:
			for condition in adapt_condition.conditions:
				if (
					condition is StateCondition
					and condition.state == &"Adapted"
					and not condition.present
				):
					has_not_adapted = true

				if (
					condition is StatCondition
					and condition.stat == StatConditionScript.Stat.AURA
					and condition.comparator == BattleCondition.Comparator.GE
					and condition.value >= 5
				):
					has_aura_for_adapt = true

		if not has_not_adapted:
			_fail("Stone Guardian uses Adaptation again after it has already adapted")

		if not has_aura_for_adapt:
			_fail("Stone Guardian can use Adaptation without enough AP")

		if adapt_branch != null:
			var paid_adaptation := false

			for step in adapt_branch.if_steps:
				if (
					step is TurnStep
					and (step as TurnStep).ability == adaptation
					and (step as TurnStep).pay_cost
				):
					paid_adaptation = true

			if not paid_adaptation:
				_fail("Stone Guardian does not spend AP when using Adaptation")

	var marks_adapted := false

	if adaptation != null:
		for step in adaptation.action_sequence.walk():
			if (
				step is StateStep
				and step.mode == StateStep.Mode.ADD
				and step.state != null
				and step.state.name == "Adapted"
			):
				marks_adapted = true

	if not marks_adapted:
		_fail("Adaptation does not mark the Guardian as already adapted")

	var has_bleed := false
	var has_held_drill := false

	if finisher != null:
		for step in finisher.walk():
			if step is ActorSpriteStep and step.animation == &"Bleed":
				has_bleed = true

			if step is TurnStep and step.ability != null and step.ability.name == "Drill":
				if step.ability.resource_path.ends_with("DrillFinisher.tres"):
					for sub_step in step.ability.action_sequence.walk():
						if (
							sub_step is EffectStep
							and sub_step.mode == EffectStep.Mode.HOLD
							and sub_step.effect_name == &"Drill"
						):
							has_held_drill = true

	if not has_bleed:
		_fail("Stone Guardian finisher does not play Mira's Bleed animation")

	if not has_held_drill:
		_fail("Stone Guardian finisher does not hold the Drill effect for the cutscene")

	var ctx := _test_context(Party.Leader)
	var actor_turn = ActorTurnConditionScript.new()
	actor_turn.actor = ActorRef.new(ActorRef.Mode.CASTER)
	actor_turn.parity = ActorTurnConditionScript.Parity.EVEN
	var previous_turns := Party.Leader.turns_taken
	Party.Leader.turns_taken = 1

	if actor_turn.check(ctx):
		_fail("Actor turn condition matched the first turn as even")

	Party.Leader.turns_taken = 2

	if not actor_turn.check(ctx):
		_fail("Actor turn condition did not match the second turn as even")

	Party.Leader.turns_taken = previous_turns

	for actor in [Party.Leader, Party.Member1]:
		if actor == null:
			continue

		var weak := Query.get_weak_color(actor.main_color)

		if battle.color_relation(actor.main_color, weak) != Wheel.Relation.WEAK:
			_fail("Weak color for " + actor.codename + " was not actually weak")

	Event.remove_flag(&"Event/StoneGuardianFinisher")
	print("BATTLE_TEST_GUARDIAN_PATTERN ok")


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
	var set_current := BattleFlowStep.new()
	set_current.mode = BattleFlowStep.Mode.SET_CURRENT
	set_current.actor = ActorRef.new(ActorRef.Mode.CASTER)
	await set_current.run(_test_context(battle.Troop[0]))

	if battle.CurrentChar != battle.Troop[0]:
		_fail("Set current step did not change the battle's current actor")

	battle.CurrentChar = previous_current

	var await_animation := ActorSpriteStep.new()
	await_animation.mode = ActorSpriteStep.Mode.AWAIT_ANIMATION
	await_animation.actor = ActorRef.new(ActorRef.Mode.CASTER)
	await await_animation.run(_test_context(caster))

	print("BATTLE_TEST_NEW_STEP_MODES ok")


## Finds the branch whose immediate if-branch makes an actor use an ability.
func _find_branch_with_ability(step: BattleStep, ability_name: String) -> BranchStep:
	if step is SequenceStep:
		var sequence := (step as SequenceStep).sequence

		if sequence != null:
			for child in sequence.steps:
				var found := _find_branch_with_ability(child, ability_name)

				if found != null:
					return found

		return null

	if step is not BranchStep:
		return null

	var branch := step as BranchStep

	for child in branch.if_steps:
		if (
			child is TurnStep
			and (child as TurnStep).ability != null
			and (child as TurnStep).ability.name == ability_name
		):
			return branch

	for child in branch.if_steps:
		var found := _find_branch_with_ability(child, ability_name)

		if found != null:
			return found

	for child in branch.else_steps:
		var found := _find_branch_with_ability(child, ability_name)

		if found != null:
			return found

	return null


func _weak_color_against(target: Actor) -> Color:
	for i in 360:
		var candidate := Color.from_hsv(float(i) / 360.0, 0.9, 1.0)

		if battle.color_relation(candidate, target.main_color) == Wheel.Relation.WEAK:
			return candidate

	return Color.WHITE


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
	var mira := ActorRef.new(ActorRef.Mode.CODENAME)
	mira.codename = &"Mira"
	event.caster = mira

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


## Non-holding events must not delay the turn, but the background queue still
## runs them one at a time so their dialogues cannot open on top of each other.
func _test_battle_events_run_in_order() -> void:
	var first_flag := &"BattleTestEventOrderA"
	var second_flag := &"BattleTestEventOrderB"
	Event.remove_flag(first_flag)
	Event.remove_flag(second_flag)

	var long_wait := WaitStep.new()
	long_wait.duration = 0.2

	var first_sequence := ActionSequence.new()
	first_sequence.steps.append(long_wait)

	var first := BattleEvent.new()
	first.result = BattleEvent.RES.SEQUENCE
	first.sequence = first_sequence
	first.on_run_flag = first_flag

	var short_wait := WaitStep.new()
	short_wait.duration = 0.01

	var second_sequence := ActionSequence.new()
	second_sequence.steps.append(short_wait)

	var second := BattleEvent.new()
	second.result = BattleEvent.RES.SEQUENCE
	second.sequence = second_sequence
	second.on_run_flag = second_flag

	Global.bt.queue_event(first)
	Global.bt.queue_event(second)
	await Event.wait(0.1)

	print(
		"BATTLE_TEST_EVENT_ORDER early a=", Event.check_flag(first_flag),
		" b=", Event.check_flag(second_flag),
	)

	if Event.check_flag(second_flag):
		_fail("Battle events overlapped instead of running in order")

	await Global.bt.wait_for_event_queue()

	print(
		"BATTLE_TEST_EVENT_ORDER done a=", Event.check_flag(first_flag),
		" b=", Event.check_flag(second_flag),
	)

	if not Event.check_flag(first_flag):
		_fail("First battle event did not finish")

	if not Event.check_flag(second_flag):
		_fail("Queued battle event did not run")

	Event.remove_flag(first_flag)
	Event.remove_flag(second_flag)


func _test_battle_event_conditions() -> void:
	var flag := &"BattleTestEventCondition"
	var condition := FlagConditionScript.new()
	condition.expression = &"BattleTestEventCondition = 1"

	var event := BattleEvent.new()
	event.condition = condition
	event.result = BattleEvent.RES.SEQUENCE

	Event.remove_flag(flag)

	if event.check():
		_fail("Battle event passed while its flag condition was false")

	Event.add_flag(flag, 1)

	if not event.check():
		_fail("Battle event did not pass its flag condition")

	var health := StatConditionScript.new()
	var ref := ActorRef.new(ActorRef.Mode.CODENAME)
	ref.codename = Party.Leader.codename
	health.actor = ref
	health.comparator = BattleCondition.Comparator.GT
	health.value = 0
	event.condition = health

	if not event.check():
		_fail("Battle event did not pass its stat condition")

	Event.remove_flag(flag)

	# The Stone Guardian's only remaining event is the one-shot below-200
	# dialogue; its old low-aura/adaptation/finisher events were replaced by a
	# single authored turn sequence. The dialogue must not fire after the boss
	# is already defeated.
	var guardian := load("res://database/BattleSeq/StoneGuardianBoss.tres") as BattleSequence
	var low_health_event := guardian.Events[0]
	var low_health := low_health_event.condition as AllCondition

	if low_health == null or low_health.conditions.size() != 2:
		_fail("Stone Guardian below-200 event lost its condition guard")
	else:
		var health_check := low_health.conditions[0] as StatCondition

		if health_check == null or health_check.stat != StatConditionScript.Stat.HEALTH:
			_fail("Stone Guardian below-200 event lost its health condition")
		elif health_check.comparator != BattleCondition.Comparator.LT or health_check.value != 200:
			_fail("Stone Guardian below-200 health condition changed")

	if low_health_event.dialog_cue != "stone_guardian_still_standing":
		_fail("Stone Guardian below-200 event lost its dialogue cue")

	# Migrated data: SkritcherRootDaze's single FORCE_MOVE event must keep its
	# actor and turn condition.
	var skritcher := load("res://database/BattleSeq/SkritcherRootDaze.tres") as BattleSequence
	var skritcher_event := skritcher.Events[0]

	if (
		skritcher_event.caster == null
		or skritcher_event.caster.mode != ActorRef.Mode.CODENAME
		or skritcher_event.caster.codename != &"SkritcherRoot"
	):
		_fail("Skritcher Root event lost its forced move caster")

	if not (skritcher_event.condition is TurnCondition):
		_fail("Skritcher Root event lost its turn condition")

	# An empty event actor falls back to the current actor.
	var fallback := BattleEvent.new()

	if fallback._resolve_event_actor() != battle.CurrentChar:
		_fail("Battle event did not fall back to the current actor")

	# Both a bare dialogue name and a path picked in the inspector resolve to
	# the name Textbox and Passive expect.
	var dialog_path := BattleEvent.new()
	dialog_path.dialog_file = "res://database/Text/story_0.dialogue"

	if dialog_path._dialog_name() != "story_0":
		_fail("Battle event did not normalize a dialogue path")

	var forced := BattleEvent.new()
	forced.move_action = BattleEvent.MoveAction.ITEM

	if forced._bt_action() != Actor.BtAction.ITEM:
		_fail("Battle event did not map its forced move action")

	var run_flag := &"BattleTestEventRunFlag"
	var setter := BattleEvent.new()
	setter.result = BattleEvent.RES.SEQUENCE
	setter.on_run_flag = run_flag
	setter.on_run_flag_value = true
	Event.remove_flag(run_flag)
	await setter.run()

	if not Event.check_flag(run_flag):
		_fail("Battle event did not set its on-run flag")

	Event.remove_flag(run_flag)


func _test_aura_break_followup() -> void:
	var saved_char := battle.CurrentChar
	var saved_target := battle.CurrentTarget
	var saved_ability := battle.CurrentAbility
	var saved_follow := battle.follow_up_next
	var target: Actor = await battle.add_to_troop(load("res://database/Enemies/Dummy.tres").duplicate())

	if target == null:
		_fail("Could not add a target for the aura-break follow-up test")
		return

	target.max_hp = 9999
	target.set_health(9999)
	target.max_aura = 20
	target.set_aura(1)
	battle.CurrentChar = Party.Leader
	battle.CurrentTarget = target
	battle.CurrentAbility = Ability.nothing()
	battle.follow_up_next = false
	var weak := _weak_color_against(target)
	battle.damage(target, false, true, 200, false, false, false, weak)
	print("BATTLE_TEST_AURA_FOLLOW aura=", target.aura, " follow=", battle.follow_up_next)

	if target.aura != 0:
		_fail("The aura-break test target did not lose all of its AP")

	if not battle.follow_up_next:
		_fail("Breaking an aura did not grant a follow-up")

	battle.CurrentChar = saved_char
	battle.CurrentTarget = saved_target
	battle.CurrentAbility = saved_ability
	battle.follow_up_next = saved_follow
	battle.delete_actor(target)


func _test_self_target_ai_move() -> void:
	var saved_char := battle.CurrentChar
	var saved_target := battle.CurrentTarget
	var saved_ability := battle.CurrentAbility
	var saved_turn := battle.Turn
	var actor: Actor = await battle.add_to_troop(load("res://database/Enemies/Dummy.tres").duplicate())

	if actor == null:
		_fail("Could not add an actor for the self-target AI test")
		return

	var sturdy := load("res://database/Abilities/SturdyGuard.tres") as Ability
	actor.health = actor.max_hp
	actor.aura = actor.max_aura
	actor.abilities = [sturdy]
	actor.standard_attack = null
	battle.CurrentChar = actor
	battle.CurrentTarget = Party.Leader
	battle.Turn = 900
	actor.battle_log = [Actor.log_entry.new()]
	await battle.ai_move(actor, false)
	print("BATTLE_TEST_SELF_TARGET barrier=", actor.has_state("Barrier"))

	if not actor.has_state("Barrier"):
		_fail("A self-target AI move did not apply its state")

	battle.CurrentChar = saved_char
	battle.CurrentTarget = saved_target
	battle.CurrentAbility = saved_ability
	battle.Turn = saved_turn
	battle.delete_actor(actor)


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

	var health = StatConditionScript.new()
	health.stat = StatConditionScript.Stat.HEALTH
	health.actor = ActorRef.new(ActorRef.Mode.CASTER)
	health.comparator = BattleCondition.Comparator.GT
	health.value = 0

	if not health.check(ctx):
		_fail("Stat condition did not pass for a living caster's health")

	var aura = StatConditionScript.new()
	aura.stat = StatConditionScript.Stat.AURA
	aura.actor = ActorRef.new(ActorRef.Mode.CASTER)
	aura.comparator = BattleCondition.Comparator.EQ
	aura.value = mira.aura

	if not aura.check(ctx):
		_fail("Stat condition did not pass when comparing aura with itself")

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

	# Heat Wave's "nothing happened" guard checks for KnockedOut. Lethal damage
	# drops health to zero before death() gets to add that state, so the
	# condition has to treat a zero-health actor as knocked out already.
	var downed_group = GroupStateConditionScript.new()
	downed_group.group = ActorGroup.Kind.TROOP
	downed_group.include_dead = true
	downed_group.state = &"KnockedOut"
	downed_group.present = false
	downed_group.group_match = GroupStateConditionScript.GroupMatch.ALL

	var saved_health: Array[int] = []

	for actor in battle.Troop:
		saved_health.append(actor.health)
		actor.health = 0

	var downed_lacks_knocked_out: bool = downed_group.check(ctx)

	for i in battle.Troop.size():
		battle.Troop[i].health = saved_health[i]

	if downed_lacks_knocked_out:
		_fail("Group state condition treated zero-health actors as lacking KnockedOut")

	var summons = CollectionConditionScript.new()
	summons.collection = CollectionConditionScript.Collection.SUMMONED_ALLIES
	summons.actor = ActorRef.new(ActorRef.Mode.CASTER)
	summons.empty = false

	if not summons.check(ctx):
		_fail("Collection condition did not pass for a populated summon list")

	if target == null:
		_fail("Condition test lost its target")
		return

	print("BATTLE_TEST_CONDITIONS ok")


## Records the caster's animation when its ability sequence starts, so a test
## can tell whether a requested action wind-up played before the ability.
class AnimationCaptureStep extends BattleStep:
	var played := false
	var animation: StringName = &""

	func run(ctx: ActionSequenceContext) -> void:
		played = true

		if ctx.caster != null and ctx.caster.node != null:
			animation = ctx.caster.node.animation
