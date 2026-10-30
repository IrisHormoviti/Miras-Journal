extends Node2D

var TurnOrder: Array[Actor]
var CurrentChar: Actor
var Troop: Array[Actor]
var Turn: int
@onready var Bt: Battle = get_parent()
# Missed
var miss: bool
## Critical Hit
var crit: bool
## The current sequence has been interrupted by something like a trap, so it
## stops dealing damage.
var interrupted := false
## Per target sequences still running, awaited before ending an AOE turn
var seq_running := 0
signal states_handled
signal additional_done


func play(nam: String, tar: Actor) -> void:
	TurnOrder = Bt.TurnOrder
	CurrentChar = Bt.CurrentChar
	interrupted = false
	Bt.Action = true
	CurrentChar.node.z_index = 1
	Loader.battle_bars(2)
	Battle.tween(self, "position", position, 0, Tween.EASE_IN_OUT, Tween.TRANS_QUART)
	if not has_method(nam): OS.alert("Invalid action sequence"); Bt.end_turn(); return
	seq_running = 0

	if Bt.CurrentAbility.is_aoe():
		await play_aoe(nam)
	else:
		roll_rng(tar)
		await held(nam, tar)
		Bt.end_turn()


## To make an AOE action sequence there needs to be a conditional for if the target is the CurrentChar.
## After the current char does their stuff, the additional_done signal needs to be emmited for the rest of the targets to act
func play_aoe(nam: String) -> void:
	if Bt.CurrentAbility.AOE_AdditionalSeq:
		print("AOE additional sequence")
		roll_rng(CurrentChar)
		held(nam, CurrentChar, true)
		await additional_done

	var fact: Array[Actor] = Bt.get_target_faction().duplicate()

	if CurrentChar in fact: fact.erase(CurrentChar)

	for i in fact:
		interrupted = false
		roll_rng(i)
		held(nam, i, true)
		print("AOE sequence on ", i.first_name)
		await Event.wait(Bt.CurrentAbility.aoe_stagger)

	while seq_running > 0: await Event.wait()
	Bt.end_turn()


## Runs one sequence while holding the turn, so only the funnels above can end
## the turn once everything is done. count tracks AOE completion instead of
## counting end_turns.
func held(nam: String, tar: Actor, count := false) -> void:
	if count: seq_running += 1
	Bt.hold_turn()
	await call(nam, tar)
	Bt.release_turn()
	if count: seq_running -= 1


func roll_rng(tar: Actor) -> void:
	miss = false
	crit = false

	if not tar.cant_dodge or tar.has_state("Bound") or tar.has_state("Soaked"):
		if randf_range(0, 1) > Bt.CurrentAbility.success_chance and not Bt.no_misses: miss = true

	if randf_range(0, 1) < Bt.CurrentAbility.crit_chance and not Bt.no_crits and not miss: crit = true

################################################


func handle_states() -> void:
	var chara := Bt.CurrentChar

	for state: State in chara.states:
		print("Handling ", state.name)
		if state.turns > -1:
			state.turns -= 1

			if state.turns == 0:
				state.queue_remove = true
				Bt.anim("", chara)

		if not state.queue_remove:
			match state.filename:
				"AuraBreak":
					if chara.aura != 0:
						state.queue_remove = true

				"Burned":
					#chara.node.get_node("State").play("Burned")
					Bt.focus_cam(chara, 0.3)
					Bt.play_sound("BurnWoosh", chara)
					Bt.damage(chara, true, true, randi_range(3, 12), false, true, true, Colorizer.ElementColor.get("heat"))
					await get_tree().create_timer(0.8).timeout

				"Poisoned":
					state.turns += 1
					#chara.node.get_node("State").play("Poisoned")
					Bt.focus_cam(chara, 0.3)
					Bt.damage(chara, true, true, abs(state.turns), false, true, true, Colorizer.ElementColor.get("corruption"))
					await get_tree().create_timer(0.8).timeout

				"Confused":
					var luck := randi_range(state.turns, 1)
					print("Confusion dice roll: ", luck)
					if luck < -1:
						chara.remove_state(state.name)
						Bt.battle_msg("confusion_recover")
					elif luck == -1 or not chara.controllable:
						var choices: Array[Ability] = chara.abilities.duplicate()
						choices.append(chara.standard_attack)
						chara.next_move = choices.pick_random()
						chara.next_action = Actor.BtAction.MAGIC
						chara.next_target = TurnOrder.pick_random()

						if chara.controllable:
							Bt.battle_msg("confusion_lose_control")
						else:
							if chara == chara.next_target and chara.next_move.target == Ability.T.ONE_ENEMY:
								Bt.battle_msg("confusion_hit_self")
							elif chara.next_target in Bt.get_ally_faction(chara) and chara.next_move.target == Ability.T.ONE_ENEMY:
								Bt.battle_msg("confusion_hit_ally")

					state.turns -= 1

				"Leeched":
					if state.inflicter in TurnOrder:
						Bt.play_effect("LeechGrab1", chara, Vector2.ZERO, false, true)
						Bt.focus_cam(chara, 0.3)
						if chara.damage_received_this_turn == 0:
							Bt.damage(chara, true, true, 4, false, true, true, Colorizer.ElementColor.get("natural"))

						var dmg: int = chara.damage_received_this_turn
						await Bt.await_anim($LeechGrab1)
						$LeechGrab1.play("LeechGrab2")
						Bt.focus_cam(state.inflicter, 0.5, 40)
						await Battle.tween(
							$LeechGrab1, "global_position", 
							state.inflicter.node.global_position, 0.5,
							Tween.EASE_OUT, Tween.TRANS_QUART
							)
						Bt.heal(state.inflicter, dmg)
						$LeechGrab1.play("LeechGrab3")
						await Bt.await_anim($LeechGrab1, "LeechGrab3")
						$LeechGrab1.queue_free()
					else: chara.remove_state(state)
				"Aggro":
					if state.inflicter not in TurnOrder or state.inflicter.has_state("KnockedOut"):
						chara.remove_state(state)
						chara.next_target = null

				"Zapped":
					if randi_range(0, 6) > 1:
						Bt.focus_cam(chara)
						Bt.battle_msg("shock")
						chara.next_action = Actor.BtAction.ACT
						chara.next_move = Ability.nothing()
						await Bt.shake_actor(chara)

				"KnockedOut":
					if chara.health > 0:
						var saving_throw := randf()
						var revive_chance: float = chara.health_ratio()
						print("Revive chance: %d / %d = %.2f " % [chara.health, chara.max_hp, revive_chance])
						print("Saving throw: %.2f" % [saving_throw])
						if revive_chance == 0.0:
							print("Character is knocked out, skip turn")
							chara.next_action = Actor.BtAction.ACT
							chara.next_move = Ability.nothing()
						elif saving_throw <= (revive_chance):
							chara.remove_state(state)
						else:
							Bt.focus_cam(chara, 0.5, 10)
							Bt.battle_msg("cant_recover")
							await Bt.shake_actor(chara)
							chara.next_action = Actor.BtAction.ACT
							chara.next_move = Ability.nothing()

				"Frozen":
					Bt.focus_cam(chara)
					Bt.battle_msg("frozen")
					chara.next_action = Actor.BtAction.ACT
					chara.next_move = Ability.nothing()
					await Bt.shake_actor(chara)

	Bt.remove_queued_states(chara)
	chara.damage_received_this_turn = 0
	states_handled.emit()


func end_turn_checks() -> void:
	var chara := CurrentChar
	Bt.remove_queued_states(chara)


#region Attacks
func StickAttack(target: Actor) -> void:
	Bt.zoom()
	Bt.focus_cam(target, 0.5, 30)
	Bt.anim("Attack1")
	Bt.jump_to_target(CurrentChar, target, Vector2(Bt.offsetize(-30), -30), 4)
	await Bt.anim_done
	Bt.move(CurrentChar, target.node.position, 0.5, Tween.EASE_IN)
	Bt.play_sound("Attack2", CurrentChar)
	Bt.screen_shake(15, 0.2)
	Bt.damage(target)
	Bt.anim("Attack2")
	Bt.play_effect("SimpleHit", target)
	await get_tree().create_timer(0.4).timeout
	Bt.return_cur()
	Bt.anim()

#endregion

################################################


#region Abilities
func SoulGrasp(target: Actor) -> void:
	Bt.zoom(6)
	Bt.focus_cam(target, 1)
	Bt.anim("Cast", CurrentChar)
	Bt.play_effect("SoulTap", target)
	await Event.wait(1)
	if crit: target.add_state("Confused")
	await Bt.shake_actor(target, 1)
	Bt.screen_shake(8, 0.1)
	Bt.damage(target, true, true)
	await Event.wait(1)
	Bt.anim()


func RedShift(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target, 1)
	Bt.play_effect("ToxicSplash", target)
	await Event.wait(0.8)
	Bt.screen_shake(8, 0.1)
	Bt.damage(target, true, true, Query.calc_num() + (Query.calc_num() * target.states.size()))
	await Event.wait(1)
	Bt.anim()

#endregion

################################################


#region Death sequences
func FlyAway(chara: Actor) -> void:
	Bt.hold_turn()
	Bt.focus_cam(chara, 0.5)
	Bt.zoom(6)
	await Event.wait(1, false)
	chara.node.flip_h = true
	Bt.anim("Fly", chara)
	Bt.battle_msg("retreat", chara.first_name)
	Bt.move(chara, Vector2(150, -150), 2)
	await Event.wait(2.5, false)
	Bt.death(chara)
#endregion

################################################


#region Battle events
## Cutscene and boss sequences are authored as ActionSequence resources in
## database/Sequences and run by BattleEvent, so they no longer live here.
#endregion
