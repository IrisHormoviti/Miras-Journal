extends Node

const BATTLE_SCENE := preload("res://codings/Common/Battle.tscn")
const TEST_SEQUENCE := preload("res://tests/BattleTestSequence.tres")
const TEST_DAMAGE := 5
const SMALL_SHOCK := preload("res://database/Abilities/SmallShock.tres")
const ICY_DRIZZLE := preload("res://database/Abilities/IcyDrizzle.tres")

var battle: Battle
var failed := false


func _ready() -> void:
	var room := Room.new()
	room.name = "BattleTestRoom"
	room.camera_index = CameraIndex.new()
	room.camera_index.spawn_player = false
	room.camera_index.z = 3
	add_child(room)

	Battle.sequence = TEST_SEQUENCE
	Battle.attacker = null
	Battle.battle_advantage = 0
	battle = BATTLE_SCENE.instantiate()
	add_child(battle)

	await get_tree().create_timer(3.0).timeout

	if not is_instance_valid(battle) or battle.Troop.is_empty():
		_fail("Battle test failed to start")
		get_tree().quit(1)
		return

	print("BATTLE_TEST_READY")
	await _test_action()
	await _test_ability("Small Shock", SMALL_SHOCK, battle.Troop[0], "Zapped")
	await _test_aoe()
	await _test_trap_interrupt()
	await _test_miss()
	await _test_auto_idle()
	_test_branch_outcomes()
	print("BATTLE_TEST_DONE failed=", failed)
	get_tree().quit(1 if failed else 0)


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _test_action() -> void:
	var caster := Party.Leader
	var target := battle.Troop[0]
	if caster == null or target == null:
		_fail("Battle test has no caster or target")
		get_tree().quit(1)
		return

	var ability := Ability.nothing().duplicate()
	ability.name = "BattleTestHit"

	var sequence := ActionSequence.new()
	var wait := WaitStep.new()
	wait.duration = 0.1
	var damage := DamageStep.new()
	var power := ValueRef.new()
	power.mode = ValueRef.Mode.FIXED
	power.value = TEST_DAMAGE
	damage.power = power
	damage.magic_mode = DamageStep.MagicMode.PHYSICAL
	sequence.steps.append(wait)
	sequence.steps.append(damage)
	ability.action_sequence = sequence

	var before := target.Health
	await battle.use_ability_now(caster, ability, target)
	var after := target.Health
	print("BATTLE_TEST_HIT before=", before, " after=", after)

	if after >= before:
		_fail("Battle test did not deal damage")

	if battle.lock_turn or battle.lock_count != 0:
		_fail("Battle test left the turn locked")


func _test_ability(label: String, ability: Ability, target: Actor, state: String) -> void:
	var test_ability := ability.duplicate() as Ability
	test_ability.name = label
	test_ability.SucessChance = 1
	test_ability.CritChance = 1
	battle.no_misses = true
	battle.no_crits = false

	var before := target.Health
	await battle.use_ability_now(Party.Leader, test_ability, target)
	var after := target.Health
	print("BATTLE_TEST_", label.to_upper().replace(" ", "_"), " before=", before, " after=", after, " state=", target.has_state(state))

	if after >= before:
		_fail(label + " did not deal damage")
	if not target.has_state(state):
		_fail(label + " did not apply " + state)
	if battle.lock_turn or battle.lock_count != 0:
		_fail(label + " left the turn locked")


func _test_aoe() -> void:
	if battle.Troop.size() < 2:
		_fail("Battle test needs two enemies for AOE")
		return

	var ability := ICY_DRIZZLE.duplicate() as Ability
	ability.name = "Icy Drizzle"
	ability.SucessChance = 1
	ability.CritChance = 1
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
		_fail("Battle test needs two enemies for trap interruption")
		return

	var first := battle.Troop[0]
	var second := battle.Troop[1]
	var trap_ability := Ability.nothing().duplicate() as Ability
	trap_ability.name = "Battle Test Trap"
	trap_ability.SucessChance = 1
	var trap_sequence := ActionSequence.new()
	var trap_damage := DamageStep.new()
	var trap_power := ValueRef.new()
	trap_power.mode = ValueRef.Mode.FIXED
	trap_power.value = TEST_DAMAGE
	trap_damage.power = trap_power
	trap_damage.magic_mode = DamageStep.MagicMode.PHYSICAL
	trap_sequence.steps.append(trap_damage)
	trap_ability.action_sequence = trap_sequence

	var trap := Trap.new()
	trap.name = "Battle Test Trap"
	trap.ability = trap_ability
	var placed: Trap = await battle.apply_trap(trap, first)
	placed.inflicter = null

	var ability := Ability.nothing().duplicate() as Ability
	ability.name = "Battle Test AOE"
	ability.Target = Ability.T.AOE_ENEMIES
	ability.AOE_Stagger = 0.1
	ability.SucessChance = 1
	var sequence := ActionSequence.new()
	for i in 2:
		var damage := DamageStep.new()
		var power := ValueRef.new()
		power.mode = ValueRef.Mode.FIXED
		power.value = TEST_DAMAGE
		damage.power = power
		damage.magic_mode = DamageStep.MagicMode.PHYSICAL
		sequence.steps.append(damage)
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
	ability.SucessChance = 0
	battle.no_misses = false
	battle.no_crits = false

	var sequence := ActionSequence.new()
	var damage := DamageStep.new()
	var power := ValueRef.new()
	power.mode = ValueRef.Mode.FIXED
	power.value = TEST_DAMAGE
	damage.power = power
	damage.magic_mode = DamageStep.MagicMode.PHYSICAL
	sequence.steps.append(damage)
	ability.action_sequence = sequence

	var before := target.Health
	await battle.use_ability_now(Party.Leader, ability, target)
	print("BATTLE_TEST_MISS before=", before, " after=", target.Health)

	if target.Health != before:
		_fail("Battle test miss dealt damage")
	if battle.lock_turn or battle.lock_count != 0:
		_fail("Battle test miss left the turn locked")


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
