extends Node2D

var TurnOrder: Array[Actor]
var CurrentChar: Actor
var Troop: Array[Actor]
var Turn: int
@onready var Bt: Battle = get_parent()
@onready var t: Tween
#var target:Actor
var miss: bool
var crit: bool
signal states_handled
signal additional_done


func play(nam: String, tar: Actor) -> void:
	TurnOrder = Bt.TurnOrder
	CurrentChar = Bt.CurrentChar
	Bt.Action = true
	CurrentChar.node.z_index = 1
	Loader.battle_bars(2)
	t = create_tween()
	t.set_trans(Tween.TRANS_QUART)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position", position, 0)
	if not has_method(nam): OS.alert("Invalid action sequence"); Bt.end_turn(); return
	if Bt.CurrentAbility.is_aoe():
		play_aoe(nam)
	else:
		roll_rng(tar)
		call(nam, tar)


## To make an AOE action sequence there needs to be a conditional for if the target is the CurrentChar.
## After the current char does their stuff, the additional_done signal needs to be emmited for the rest of the targets to act
func play_aoe(nam: String) -> void:
	if Bt.CurrentAbility.AOE_AdditionalSeq:
		print("AOE additional sequence")
		roll_rng(CurrentChar)
		call(nam, CurrentChar)
		await additional_done

	var fact: Array[Actor] = Bt.get_target_faction().duplicate()
	var required_returns: int = fact.size()

	if Bt.CurrentAbility.AOE_AdditionalSeq: required_returns += 1
	if CurrentChar in fact:
		fact.erase(CurrentChar)
		required_returns -= 1

	for i in fact:
		roll_rng(i)
		call(nam, i)
		print("AOE sequence on ", i.FirstName)
		await Event.wait(Bt.CurrentAbility.AOE_Stagger)

	while Bt.aoe_returns != required_returns: await Event.wait()
	Bt.end_turn(true)


func roll_rng(tar: Actor) -> void:
	miss = false
	crit = false

	if not tar.CantDodge or tar.has_state("Bound") or tar.has_state("Soaked"):
		if randf_range(0, 1) > Bt.CurrentAbility.SucessChance and not Bt.no_misses: miss = true

	if randf_range(0, 1) < Bt.CurrentAbility.CritChance and not Bt.no_crits and not miss: crit = true

################################################


func handle_states() -> void:
	var chara := Bt.CurrentChar

	for state: State in chara.States:
		print("Handling ", state.name)
		if state.turns > -1:
			state.turns -= 1

			if state.turns == 0:
				state.QueueRemove = true
				Bt.anim("", chara)

		if not state.QueueRemove:
			match state.filename:
				"AuraBreak":
					if chara.Aura != 0:
						state.QueueRemove = true

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
					elif luck == -1 or not chara.Controllable:
						var choices: Array[Ability] = chara.Abilities.duplicate()
						choices.append(chara.StandardAttack)
						chara.NextMove = choices.pick_random()
						chara.NextAction = Actor.BtAction.MAGIC
						chara.NextTarget = TurnOrder.pick_random()

						if chara.Controllable:
							Bt.battle_msg("confusion_lose_control")
						else:
							if chara == chara.NextTarget and chara.NextMove.Target == Ability.T.ONE_ENEMY:
								Bt.battle_msg("confusion_hit_self")
							elif chara.NextTarget in Bt.get_ally_faction(chara) and chara.NextMove.Target == Ability.T.ONE_ENEMY:
								Bt.battle_msg("confusion_hit_ally")

					state.turns -= 1

				"Leeched":
					if state.inflicter in TurnOrder:
						Bt.play_effect("LeechGrab1", chara, Vector2.ZERO, false, true)
						Bt.focus_cam(chara, 0.3)
						if chara.DamageRecivedThisTurn == 0:
							Bt.damage(chara, true, true, 4, false, true, true, Colorizer.ElementColor.get("natural"))

						var dmg: int = chara.DamageRecivedThisTurn
						await $LeechGrab1.animation_finished
						t = create_tween()
						t.set_ease(Tween.EASE_OUT)
						t.set_trans(Tween.TRANS_QUART)
						$LeechGrab1.play("LeechGrab2")
						t.tween_property($LeechGrab1, "global_position", state.inflicter.node.global_position, 0.5)
						Bt.focus_cam(state.inflicter, 0.5, 40)
						await t.finished
						Bt.heal(state.inflicter, dmg)
						$LeechGrab1.play("LeechGrab3")
						await $LeechGrab1.animation_finished
						$LeechGrab1.queue_free()
					else: chara.remove_state(state)
				"Aggro":
					if state.inflicter not in TurnOrder or state.inflicter.has_state("KnockedOut"):
						chara.remove_state(state)
						chara.NextTarget = null

				"Zapped":
					if randi_range(0, 6) > 1:
						Bt.focus_cam(chara)
						Bt.battle_msg("shock")
						chara.NextAction = Actor.BtAction.ACT
						chara.NextMove = Ability.nothing()
						await Bt.shake_actor(chara)

				"KnockedOut":
					if chara.Health > 0:
						var saving_throw := randf()
						var revive_chance: float = chara.health_ratio()
						print("Revive chance: %d / %d = %.2f " % [chara.Health, chara.MaxHP, revive_chance])
						print("Saving throw: %.2f" % [saving_throw])
						if revive_chance == 0.0:
							print("Character is knocked out, skip turn")
							chara.NextAction = Actor.BtAction.ACT
							chara.NextMove = Ability.nothing()
						elif saving_throw <= (revive_chance):
							chara.remove_state(state)
						else:
							Bt.focus_cam(chara, 0.5, 10)
							Bt.battle_msg("cant_recover")
							await Bt.shake_actor(chara)
							chara.NextAction = Actor.BtAction.ACT
							chara.NextMove = Ability.nothing()

				"Frozen":
					Bt.focus_cam(chara)
					Bt.battle_msg("frozen")
					chara.NextAction = Actor.BtAction.ACT
					chara.NextMove = Ability.nothing()
					await Bt.shake_actor(chara)

	Bt.remove_queued_states(chara)
	chara.DamageRecivedThisTurn = 0
	states_handled.emit()


func end_turn_checks() -> void:
	var chara := CurrentChar
	Bt.remove_queued_states(chara)


func Default(target: Actor) -> void:
	Bt.zoom(5)
	Bt.focus_cam(CurrentChar)
	Bt.anim("Cast")
	await Event.wait(0.3)
	Bt.focus_cam(target)
	if Bt.CurrentAbility.Damage != Ability.D.NONE:
		if miss: Bt.miss()
		else:
			await Bt.damage(target, true, true)

		if crit: await Bt.damage(target, true, true)

	if Bt.CurrentAbility.InflictsState != "":
		await target.add_state(Bt.CurrentAbility.InflictsState)

	await Event.wait(0.4)
	Bt.anim()
	Bt.end_turn()


#region Attacks
func AttackMira(target: Actor) -> void:
	Bt.zoom()
	Bt.focus_cam(target, 0.5, 30)
	Bt.anim("Attack1")
	Bt.play_sound("Attack1", CurrentChar)
	Bt.jump_to_target(CurrentChar, target, Vector2(Bt.offsetize(-30), 0), 4)
	await Bt.anim_done
	if not miss:
		Bt.play_sound("Attack2", CurrentChar)
		Bt.screen_shake(15, 7, 0.2)
		Bt.anim("Attack2")
		Bt.play_effect("SimpleHit", target)
		Bt.damage(target)
	else:
		Bt.anim("Attack2")
		Bt.miss()

	if crit:
		Bt.damage(target, false, true)
		Bt.pop_num(target, "CRITICAL", Bt.CurrentAbility.WheelColor)

	await get_tree().create_timer(0.4).timeout
	Bt.return_cur()
	Bt.anim("Idle")
	Bt.end_turn()


func JumpAttack(target: Actor) -> void:
	Bt.zoom(5)
	Bt.focus_cam(target, 0.5, 30)
	Bt.anim("Attack1")
	Bt.jump_to_target(CurrentChar, target, Vector2(Bt.offsetize(-30), 0), 4)
	await Bt.anim_done
	if not miss:
		Bt.play_sound("Attack2", CurrentChar)
		Bt.damage(target, false, false)
		Bt.screen_shake(15, 7, 0.2)
		Bt.anim("Attack2")
		Bt.play_effect("SimpleHit", target)
	else: Bt.miss()
	await Event.wait(0.4)
	Bt.return_cur()
	Bt.anim("Idle")
	Bt.end_turn()


func AttackAlcine(target: Actor) -> void:
	Bt.zoom()
	Bt.focus_cam(target, 0.5, 30)
	Bt.anim("Attack1")
	await Event.wait(0.2)
	await Bt.move(CurrentChar, target.node.position + Vector2(Bt.offsetize(-57), 0), 0.4, Tween.EASE_OUT)
	if not miss:
		Bt.damage(target)
		Bt.screen_shake(8, 5, 0.1)
		Bt.anim("Attack2")
		Bt.move(target, target.node.position + Vector2(Bt.offsetize(-10), 0), 0.3, Tween.EASE_OUT)
		Bt.move(CurrentChar, target.node.position + Vector2(Bt.offsetize(-70), 0), 0.3, Tween.EASE_OUT)
		await Event.wait(0.6)
		if crit:
			Bt.damage(target, false, true)
			Bt.screen_shake(15, 7, 0.3)
			Bt.pop_num(target, "CRITICAL", Bt.CurrentAbility.WheelColor)
		else:
			Bt.damage(target, false, false)
			Bt.screen_shake(10, 7, 0.3)

		Bt.move(target, target.node.position + Vector2(Bt.offsetize(10), 0), 0.5, Tween.EASE_OUT)
		await CurrentChar.node.animation_finished
	else: Bt.miss()
	Bt.anim("Idle")
	await Event.wait(0.3)
	Bt.return_cur()
	Bt.end_turn()


func AttackDaze(target: Actor) -> void:
	Bt.zoom(5)
	Bt.focus_cam(target)
	Bt.anim("Attack1")
	await Bt.move(CurrentChar, CurrentChar.node.position + Vector2(10, -20), 0.1)
	Bt.play_effect("Slice", target, Vector2.ZERO, true)
	await Bt.move(CurrentChar, target.node.position + Vector2(0, 15), 0.1, Tween.EASE_IN)
	Bt.anim("Attack2")
	if not miss:
		Bt.play_sound("Attack2", CurrentChar)
		Bt.damage(target, false, false)
		Bt.screen_shake(5, 7, 0.2)
		Bt.shake_actor()
		await Bt.move(CurrentChar, target.node.position + Vector2(Bt.offsetize(45), 0), 0.2, Tween.EASE_OUT)
		if crit:
			await Event.wait(0.5)
			Bt.anim("Attack3")
			await Event.wait(0.2)
			Bt.zoom(6, 0.2)
			Bt.pop_num(target, "CRITICAL", Bt.CurrentAbility.WheelColor)
			await Bt.move(CurrentChar, target.node.position + Vector2(Bt.offsetize(-30), 0), 0.2, Tween.EASE_OUT)
			await Event.wait(0.5)
			Bt.play_effect("SimpleHit", target)
			Bt.screen_shake(15, 7, 0.2)
			Bt.damage(target, false, true)
			await Event.wait(0.7)
	else: Bt.miss()
	await Event.wait(0.3)
	await Bt.return_cur()
	Bt.anim("Idle")
	Bt.end_turn()


func AttackAsteria(target: Actor) -> void:
	Bt.zoom()
	Bt.anim("Attack1")
	await Event.wait(0.1)
	await Bt.focus_cam(target, 0.3, 30)
	Bt.play_effect("Scarf1", target, Vector2.ZERO, false, true)
	await Event.wait(0.2)
	if not miss:
		Bt.play_sound("Attack2", CurrentChar)
		Bt.damage(target)
		Bt.screen_shake()
	else: Bt.miss()
	await Event.wait(0.5)
	roll_rng(target)
	if not miss:
		Bt.play_sound("Attack2", CurrentChar)
		Bt.damage(target)
		Bt.screen_shake()
	else: Bt.miss()
	await $Scarf1.animation_finished
	if crit:
		$Scarf1.play("Scarf3")
		await Event.wait(0.6)
		Bt.play_sound("Attack2", CurrentChar)
		Bt.damage(target, false, true)
		Bt.screen_shake()
		Bt.pop_num(target, "CRITICAL", Bt.CurrentAbility.WheelColor)
	else:
		$Scarf1.play("Scarf2")

	await $Scarf1.animation_finished
	$Scarf1.queue_free()
	Bt.anim()
	Bt.end_turn()


func Nothing(target: Actor) -> void:
	Bt.end_turn()


func Pass(target: Actor) -> void:
	target.add_aura(round(target.MaxAura * 0.25))
	Bt.end_turn()


func TestState(target: Actor) -> void:
	Bt.focus_cam(target)
	target.add_state(Bt.CurrentAbility.InflictsState)
	await Event.wait(1)
	Bt.end_turn()


func StickAttack(target: Actor) -> void:
	Bt.zoom()
	Bt.focus_cam(target, 0.5, 30)
	Bt.anim("Attack1")
	Bt.jump_to_target(CurrentChar, target, Vector2(Bt.offsetize(-30), -30), 4)
	await Bt.anim_done
	Bt.move(CurrentChar, target.node.position, 0.5, Tween.EASE_IN)
	Bt.play_sound("Attack2", CurrentChar)
	Bt.damage(target)
	Bt.screen_shake(15, 7, 0.2)
	Bt.anim("Attack2")
	Bt.play_effect("SimpleHit", target)
	await get_tree().create_timer(0.4).timeout
	Bt.return_cur()
	Bt.anim()
	Bt.end_turn()


func WarpAttack(target: Actor) -> void:
	Bt.zoom()
	Bt.move(CurrentChar, Vector2(Bt.offsetize(30), Bt.initial.y), 0.4)
	Bt.focus_cam(target, 0.6, 30)
	CurrentChar.node.get_node("Shadow").hide()
	await Bt.anim("Attack1")
	CurrentChar.node.position = Vector2(target.node.position.x + Bt.offsetize(-30), target.node.position.y)
	Bt.move(CurrentChar, target.node.position + Vector2(Bt.offsetize(-5), 0), 0.8)
	Bt.anim("Attack2")
	await Event.wait(0.2)
	if not miss:
		Bt.play_sound("Attack2", CurrentChar)
		Bt.damage(target)
		Bt.screen_shake()
	else: Bt.miss()
	await Event.wait(0.7)
	CurrentChar.node.position = Bt.initial + Vector2(Bt.offsetize(-50), 0)
	Bt.return_cur()
	CurrentChar.node.get_node("Shadow").show()
	Bt.end_turn()
	var temp := CurrentChar
	temp.node.play_backwards("Attack1")
	await temp.node.animation_finished
	Bt.anim("Idle", temp)


func RemoteAttack(target: Actor) -> void:
	Bt.zoom()
	Bt.focus_cam(CurrentChar, 0.5, 30)
	Bt.anim("Attack1")
	await Event.wait(0.6)
	await Bt.screen_shake(7, 5, 0.2)
	await Bt.focus_cam(target, 1, 30)
	Bt.play_effect("RemoteHit", target)
	await Event.wait(0.4)
	if not miss:
		Bt.play_sound("Attack2", CurrentChar)
		Bt.damage(target)
		Bt.screen_shake()
	else: Bt.miss()
	await Event.wait(0.5)
	Bt.anim()
	Bt.end_turn()


func CloseupAttack(target: Actor) -> void:
	Bt.zoom()
	Bt.focus_cam(target)
	Bt.anim("Attack1")
	await Bt.move(CurrentChar, target.node.position + Vector2(Bt.offsetize(-20), 0), 0.5)
	Bt.anim("Attack2")
	await Event.wait(0.2)
	if not miss:
		Bt.play_sound("Attack2", CurrentChar)
		Bt.damage(target)
		Bt.play_effect("SimpleHit", target)
		Bt.screen_shake(18)
	else: Bt.miss()
	await Event.wait(0.5)
	Bt.return_cur()
	Bt.anim()
	Bt.end_turn()


func AOEAttack(target: Actor) -> void:
	if target == CurrentChar:
		Bt.focus_cam(CurrentChar)
		Bt.anim("Attack1")
		Bt.move(CurrentChar, Vector2(Bt.offsetize(-20), 0), 0.5, Tween.EASE_OUT)
		await Event.wait(0.5)
		Bt.move_cam(Vector2(Bt.offsetize(20), 0), 1)
		Bt.zoom(4.5, 1)
		await Bt.anim("Attack2")
		additional_done.emit()
		await Event.wait(1)
		Bt.return_cur()
		Bt.anim()
	else:
		if miss: Bt.miss(target)
		else:
			Bt.play_sound("Attack2", CurrentChar)
			Bt.damage(target)
			Bt.play_effect("SimpleHit", target)
			Bt.screen_shake(18)

	Bt.end_turn()


func CrystalHeal(target: Actor) -> void:
	if Bt.get_ally_faction().size() > 1:
		var hp_sorted_allies: Array[Actor] = Bt.get_ally_faction().duplicate()
		hp_sorted_allies.erase(CurrentChar)
		hp_sorted_allies.sort_custom(Bt.hp_sort)
		for i in hp_sorted_allies: print(i.FirstName, " - ", i.Health)
		target = hp_sorted_allies[0]

	if target.Health != target.MaxHP:
		Bt.focus_cam(CurrentChar)
		Bt.anim("Attack1")
		await Event.wait(0.5)
		Bt.focus_cam(target)
		Bt.move(CurrentChar, target.node.position, 0.5)
		Bt.anim("Attack2")
		await Event.wait(0.5)
		Bt.focus_cam(CurrentChar)
		Bt.heal(target, CurrentChar.Weapon.power)
		await Event.wait(0.5)
		Bt.death(CurrentChar)
		CurrentChar.node.hide()

	Bt.end_turn()
#endregion

################################################


#region Abilities
func Guard(target: Actor) -> void:
	Bt.zoom()
	Bt.anim("Guard")
	Bt.focus_cam(CurrentChar)
	await CurrentChar.add_state("Guarding")
	await Event.wait(0.5)
	Bt.end_turn()


func PhantomGuard(target: Actor) -> void:
	Bt.zoom()
	Bt.anim("Guard")
	Bt.focus_cam(CurrentChar)
	Bt.aura_overwrite(target, Bt.CurrentAbility.WheelColor)
	await Event.wait(0.5)
	await CurrentChar.add_state("Guarding")
	await Event.wait(0.5)
	Bt.end_turn()


func SoothingSpray(target: Actor) -> void:
	Bt.zoom(5)
	Bt.focus_cam(target, 1)
	Bt.heal(target)
	await Bt.anim("Cast")
	Bt.anim()
	Bt.end_turn()


func SoothingRain(target: Actor) -> void:
	if target == CurrentChar:
		Bt.zoom(4)
		Bt.move_cam(Vector2(-30, 0))
		await Bt.anim("Cast")
		additional_done.emit()

	Bt.heal(target)
	if crit:
		Bt.stat_change("Mag", 0.5, target)

	Bt.anim()
	Bt.end_turn()


func FlameSpark(target: Actor) -> void:
	Bt.zoom(5)
	Bt.focus_cam(CurrentChar, 0.3)
	Bt.anim("FlameSpark")
	await Event.wait(0.1)
	Bt.glow(0)
	await get_tree().create_timer(0.3).timeout
	Bt.play_effect("FlameSpark", target)
	if miss: Bt.miss()
	else:
		Bt.focus_cam(target, 0.3)
		await Event.wait(0.2)
		Bt.damage(target, true, true)
		await Event.wait(0.8)
		await target.add_state("Burned")

	await Event.wait(0.8)
	Bt.anim("Idle")
	Bt.end_turn()


func RagingFire(target: Actor) -> void:
	Bt.zoom(5)
	Bt.focus_cam(CurrentChar, 0.3, 20)
	Bt.anim("FlameSpark")
	await Event.wait(0.1)
	Bt.glow(0)
	await get_tree().create_timer(0.3).timeout
	Bt.play_effect("FlameSpark", target)
	Bt.focus_cam(target, 0.3)
	await Event.wait(0.2)
	Bt.screen_shake()
	Bt.damage(target, true, true)
	await Event.wait(0.8)
	if crit:
		await target.add_state("Burned")

	await Event.wait(0.8)
	Bt.anim("Idle")
	Bt.end_turn()


func Summon(target: Actor) -> void:
	Bt.zoom(5)
	Bt.focus_cam(CurrentChar, 0.3, 0)
	await Bt.anim("Cast")
	if CurrentChar.SummonedAllies.is_empty(): Bt.battle_msg("summon_no_friends")
	elif miss:
		Bt.battle_msg("summon_fail")
		await Event.wait(1)
	else:
		Loader.white_fadeout(1, 0.5, 0.5)
		await Event.wait(0.5)
		#FIXME
		Bt.add_to_troop(CurrentChar.SummonedAllies.pick_random())
		await Event.wait(1)

	Bt.anim()
	Bt.end_turn()


func SoulTap(target: Actor) -> void:
	Bt.zoom(6)
	Bt.focus_cam(target, 1)
	Bt.anim("Cast", CurrentChar)
	Bt.play_effect("SoulTap", target)
	await Event.wait(0.8)
	if crit: target.add_state("Confused")
	await Bt.shake_actor(target, 1, 2)
	Bt.screen_shake(5, 2, 0.1)
	Bt.damage(target, true, true)
	await Event.wait(0.5)
	Bt.anim()
	Bt.end_turn()


func SoulGrasp(target: Actor) -> void:
	Bt.zoom(6)
	Bt.focus_cam(target, 1)
	Bt.anim("Cast", CurrentChar)
	Bt.play_effect("SoulTap", target)
	await Event.wait(1)
	if crit: target.add_state("Confused")
	await Bt.shake_actor(target, 1)
	Bt.screen_shake(8, 2, 0.1)
	Bt.damage(target, true, true)
	await Event.wait(1)
	Bt.anim()
	Bt.end_turn()


func Needle(target: Actor) -> void:
	Bt.zoom(5)
	Bt.focus_cam(target, 1)
	Bt.anim("Cast", CurrentChar)
	Bt.play_effect("Needle", target, Vector2(Bt.offsetize(-15), -15), true)
	if !miss:
		await Event.wait(0.3)
		Bt.screen_shake(12, 5, 0.1)
		Bt.damage(target, false, true)
	else: Bt.miss()
	await Event.wait(1)
	Bt.anim()
	Bt.end_turn()


func AttackUp3(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target)
	await Bt.stat_change(&"Atk", Bt.CurrentAbility.Parameter, target, 3)
	await Event.wait(1)
	Bt.anim()
	Bt.end_turn()


func AttackUpNext(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target)
	await Bt.stat_change(&"Atk", Bt.CurrentAbility.Parameter, target, -2)
	await Event.wait(1)
	Bt.anim()
	Bt.end_turn()


func MagicUp3(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target)
	await Bt.stat_change(&"Mag", Bt.CurrentAbility.Parameter, target, 3)
	await Event.wait(1)
	Bt.anim()
	Bt.end_turn()


func DefenceUp3(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target)
	await Bt.stat_change(&"Def", Bt.CurrentAbility.Parameter, target, 3)
	await Event.wait(1)
	Bt.anim()
	Bt.end_turn()


func ToxicSplash(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target, 1)
	Bt.play_effect("ToxicSplash", target)
	await Event.wait(0.8)
	Bt.damage(target, true, true)
	Bt.screen_shake(8, 5, 0.1)
	await Event.wait(1)
	if crit: await target.add_state("Poisoned")
	Bt.anim()
	Bt.end_turn()


func IcyDrizzle(target: Actor) -> void:
	if target == CurrentChar:
		Bt.focus_cam(CurrentChar)
		Bt.anim("Cast")
		await Event.wait(0.5)
		Bt.move_cam(Vector2(Bt.offsetize(20), 0), 1)
		Bt.zoom(4.5, 1)
		additional_done.emit()
		await Event.wait(1)
		Bt.return_cur()
		Bt.anim()
	else:
		Bt.play_effect("Iceicle", target, Vector2(randi_range(-10, 10), randi_range(-10, 10)))
		await Event.wait(0.3)
		if not miss:
			Bt.damage(target, false, true, Query.calc_num() / 2)
			Bt.screen_shake(5)

		roll_rng(target)
		if not miss:
			Bt.play_effect("Iceicle", target, Vector2(randi_range(-10, 10), randi_range(-10, 10)))
			await Event.wait(randf_range(0, 0.5))
			Bt.damage(target, true, true, Query.calc_num() / 2)
			Bt.screen_shake(5)
			if crit: await target.add_state("Frozen")

	Bt.end_turn()


func LeechSeeds(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target, 1)
	Bt.play_effect("LeechSeeds", target)
	await Event.wait(1)
	if miss: Bt.miss()
	else:
		await target.add_state("Leeched")

	await Event.wait(0.5)
	Bt.anim()
	Bt.end_turn()


func SmallShock(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target, 1)
	#Bt.play_effect("ToxicSplash", target)
	await Event.wait(0.8)
	Bt.damage(target, true, true)
	Bt.screen_shake(8, 5, 0.1)
	await Event.wait(1)
	if crit: await target.add_state("Zapped")
	Bt.anim()
	Bt.end_turn()


func FluidBlast(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target, 1)
	await Event.wait(0.8)
	Bt.damage(target, true, true)
	Bt.screen_shake(8, 5, 0.1)
	await Event.wait(1)
	if crit: await target.add_state("Soaked")
	Bt.anim()
	Bt.end_turn()


func StaticSaber(target: Actor) -> void:
	if not is_instance_valid(target): return
	Bt.anim("Attack2", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target, 1, 0)
	await Bt.move(CurrentChar, target.node.position + Vector2(Bt.offsetize(-20), 0), 0.3, Tween.EASE_IN)
	Bt.move(CurrentChar, target.node.position + Vector2(Bt.offsetize(30), -20), 1, Tween.EASE_OUT)
	Bt.damage(target, false, true)
	Bt.screen_shake(8, 5, 0.1)
	await Event.wait(1.5)
	if crit: await target.add_state("Zapped")
	Bt.anim()
	await Bt.return_cur()
	Bt.end_turn()


func RedShift(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target, 1)
	Bt.play_effect("ToxicSplash", target)
	await Event.wait(0.8)
	Bt.damage(target, true, true, Query.calc_num() + (Query.calc_num() * target.States.size()))
	Bt.screen_shake(8, 5, 0.1)
	await Event.wait(1)
	Bt.anim()
	Bt.end_turn()


func Tighten(target: Actor) -> void:
	Bt.anim("Cast", CurrentChar)
	Bt.zoom(6)
	Bt.focus_cam(target, 1)
	#Bt.play_effect("Tighten", target)
	await Event.wait(1)
	if miss: Bt.miss()
	else:
		await target.add_state("Bound")

	await Event.wait(0.5)
	Bt.anim()
	Bt.end_turn()


func AnythingGoes(target: Actor) -> void:
	Bt.zoom()
	await Bt.focus_cam(target, 0.5, 0)
	target.remove_state("AuraOverwrite")
	await Bt.aura_overwrite(target, Color(randf_range(0.2, 0.8), randf_range(0.2, 0.8), randf_range(0.2, 0.8)), -1)
	await Event.wait(1.5)
	Bt.end_turn()


func Drill(target: Actor) -> void:
	Bt.zoom(5)
	Bt.focus_cam(target, 1)
	Bt.play_effect("Drill", target, Vector2(100, 0))
	$Drill.material = ShaderMaterial.new()
	$Drill.material.shader = load("res://database/Abilities/color_replace.gdshader")
	$Drill.material.set_shader_parameter("prev_color", Color.hex(0xff0000ff))
	$Drill.material.set_shader_parameter("new_color", CurrentChar.MainColor)
	await Event.wait(0.8)
	t = create_tween()
	t.tween_property($Drill, "position", target.node.position + Vector2(32, 0), 0.1)
	await Event.wait(0.1)
	Bt.screen_shake(5)
	Bt.shake_actor(target)
	await Event.wait(0.5)
	Bt.screen_shake()
	await Bt.damage(target, false, true, Query.calc_num(), true, false, false, Bt.CurrentChar.MainColor)
	await Event.wait(0.5)
	Bt.end_turn()


func Crusher(target: Actor) -> void:
	Bt.zoom(5)
	Bt.focus_cam(target)
	Bt.screen_shake()
	await Bt.damage(target, false, true)
	Bt.end_turn()


func HeatWave(target: Actor) -> void:
	if target == CurrentChar:
		Bt.focus_cam(CurrentChar)
		Bt.zoom(6, 0.3)
		Bt.anim("Cast")
		await Event.wait(1)
		Bt.play_effect("HeatWave", Vector2(50, 0))
		Bt.play_sound("WindShort")
		Bt.move_cam(Vector2(40, 0), 1)
		Bt.zoom(5, 1)
		await Event.wait(1)
		additional_done.emit()
		await Event.wait(0.3)
		if Bt.filter_actors_by_state(Bt.get_oposing_faction(), "Burned").is_empty():
			Bt.battle_msg("nothing_happened")
			await Event.wait(1)

		Bt.anim()
	else:
		if target.has_state("Burned"):
			await Bt.shake_actor(target)
			Bt.screen_shake(5)
			Bt.play_sound("BurnWoosh", target)
			Bt.damage(target, true, true)
		elif crit:
			target.add_state("Burned")

	Bt.end_turn()


func Thunderstorm(target: Actor) -> void:
	if target == CurrentChar:
		Bt.focus_cam(CurrentChar)
		Bt.zoom(6, 0.3)
		Bt.anim("Cast")
		await Event.wait(1)
		Bt.play_sound("WindShort")
		Bt.move_cam(Vector2(40, 0), 1)
		Bt.zoom(5, 1)
		await Event.wait(1)
		additional_done.emit()
		await Event.wait(0.3)
		Bt.anim()
	else:
		if not miss:
			await Bt.shake_actor(target)
			Bt.screen_shake(10)
			Bt.play_sound("Attack2", CurrentChar)
			Bt.damage(target, true, true)

		target.add_state("Soaked", 5)

	Bt.end_turn()


func Humidity(target: Actor) -> void:
	if target == CurrentChar:
		Bt.focus_cam(CurrentChar)
		Bt.zoom(6, 0.3)
		Bt.anim("Cast")
		await Event.wait(1)
		Bt.play_effect("HeatWave", Vector2(50, 0))
		Bt.play_sound("WindShort")
		Bt.move_cam(Vector2(Bt.offsetize(40), 0), 1)
		Bt.zoom(5, 1)
		await Event.wait(1)
		additional_done.emit()
		await Event.wait(0.3)
		if Bt.filter_actors_by_state(Bt.get_oposing_faction(), "Soaked").is_empty():
			Bt.battle_msg("nothing_happened")

		await Event.wait(1)
		Bt.anim()
	else:
		if target.has_state("Soaked"):
			await Bt.shake_actor(target)
			Bt.screen_shake(5)
			Bt.play_sound("BurnWoosh", target)
			Bt.damage(target, true, true)
		elif crit:
			target.add_state("Soaked")

	Bt.end_turn()


func Gather(target: Actor) -> void:
	await Bt.focus_cam(CurrentChar)
	CurrentChar.add_aura(CurrentChar.MaxAura)
	Bt.end_turn()


func ProtectiveField(target: Actor) -> void:
	Bt.anim("Cast")
	Bt.focus_cam(target)
	await target.add_state("MagicShield")
	Bt.anim("Guard")
	Bt.anim()
	Bt.end_turn()


func Attention(target: Actor) -> void:
	Bt.zoom()
	Bt.focus_cam(CurrentChar)
	Passive.open("banter_battle", "attention")
	await Event.wait(1)
	Bt.focus_cam(target)
	target.add_state("Aggro")
	await Event.wait(0.5)
	Bt.anim()
	Bt.end_turn()


func SturdyGuard(target: Actor) -> void:
	Bt.focus_cam(target)
	Bt.anim("Guard")
	await target.add_state("Barrier", 1)
	Bt.end_turn()


func RockThrow(target: Actor) -> void:
	Bt.zoom()
	await Bt.focus_cam(target)
	Bt.play_effect("RockThrow", target, Vector2(30, -40))
	await Event.wait(0.2)
	if miss: await Bt.miss()
	else:
		Bt.screen_shake()
		Bt.play_effect("SimpleHit", target)
		await Bt.damage(target, false, true)

	Bt.end_turn()


func Dispel(target: Actor) -> void:
	Bt.zoom()
	Bt.anim("Cast")
	await Bt.focus_cam(target)
	if target.States.is_empty():
		Bt.battle_msg("dispel_fail")
	else:
		var state: State = target.States.pick_random()
		Bt.battle_msg("dispel", state.name)
		target.remove_state(state)

	await Event.wait(1)
	Bt.anim()
	Bt.end_turn()
#endregion

################################################


#region Items
func Drink(target: Actor) -> void:
	Bt.focus_cam(CurrentChar, 0.3)
	Bt.zoom(5.5)
	print(Bt.CurrentAbility.Types)
	if Ability.TP.HEALING in Bt.CurrentAbility.Types:
		Bt.heal(CurrentChar, int(Bt.CurrentAbility.Parameter))

	await Bt.anim("Cast")
	await Event.wait(1)
	Bt.anim("", CurrentChar)
	Bt.end_turn()


func Eat(target: Actor) -> void:
	Bt.focus_cam(CurrentChar, 0.3)
	Bt.zoom(5.5)
	print(Bt.CurrentAbility.Types)
	if Ability.TP.HEALING in Bt.CurrentAbility.Types:
		Bt.heal(CurrentChar, int(Bt.CurrentAbility.Parameter))

	await Bt.anim("Cast")
	await Event.wait(1)
	Bt.anim("", CurrentChar)
	Bt.end_turn()


func ItemCure(target: Actor) -> void:
	Bt.focus_cam(CurrentChar, 0.3)
	Bt.zoom(5.5)
	print(Bt.CurrentAbility.Type)
	if Bt.CurrentAbility.Type == "Healing":
		Bt.heal(CurrentChar, int(Bt.CurrentAbility.Parameter))

	CurrentChar.remove_state(Bt.CurrentAbility.InflictsState)
	await Bt.anim("Cast")
	await Event.wait(1)
	Bt.anim()
	Bt.end_turn()


func ItemThrow(target: Actor) -> void:
	Bt.zoom(5.5)
	Bt.focus_cam(CurrentChar, 0.2)
	Bt.anim("Throw")
	await Event.wait(0.3)
	Bt.focus_cam(target)
	Bt.play_effect("Hit", target)
	Bt.screen_shake()
	Bt.damage(target, false, true, Query.calc_num(), true, false, true)
	if Bt.CurrentAbility.InflictsState != "":
		await target.add_state(Bt.CurrentAbility.InflictsState)

	await Event.wait(1)
	Bt.anim()
	Bt.end_turn()
#endregion

################################################


#region Death sequences
func FlyAway(chara: Actor) -> void:
	Bt.lock_turn = true
	Bt.focus_cam(chara, 0.5)
	Bt.zoom(6)
	await Event.wait(1, false)
	chara.node.flip_h = true
	Bt.anim("Fly", chara)
	Bt.battle_msg("retreat", chara.FirstName)
	Bt.move(chara, Vector2(150, -150), 2)
	await Event.wait(2.5, false)
	Bt.death(chara)
	Bt.end_turn()
#endregion

################################################


#region Battle events
func FirstBattle1() -> void:
	while not is_instance_valid(Global.player): await Event.wait()
	Bt.no_misses = true
	Bt.no_crits = true
	Global.player.position = Vector2(1470, 400)
	await Event.wait(2, false)
	Global.camera.enabled = false
	Bt.Troop[0].node.position.x = 50
	Bt.focus_cam(Bt.Troop[0], 0.1, 0)
	Bt.zoom(6)
	Bt.Action = true
	Battle.in_battle = true
	Loader.get_node("Can").layer = 3
	await Textbox.open("story_0", "first_cutscene")
	Loader.battle_bars(4)
	Global.player.hide()
	await Event.wait(0.5, false)
	Loader.ungray.emit()
	await Event.wait(0.3, false)
	#Hud.battle_state(true)
	#$"../EnemyUI"._on_battle_ui_target_foc(Bt.Troop[0])
	Loader.battle_bars(3)
	Bt.get_actor("Mira").node.animation = "Entrance"
	Bt.get_actor("Mira").node.frame = 2
	Bt.focus_cam(Bt.get_actor("Mira"), 3, 40)
	await Event.wait(1)
	Passive.open("story_0", "sstay_back")
	await Event.wait(1)
	Battle.in_battle = true
	await Bt.move(Bt.Troop[0], Vector2(40, 0), 1, Tween.EASE_OUT)
	await Bt.move(Bt.Troop[0], Vector2(40, 0), 1, Tween.EASE_OUT)
	$"../BattleUI".disable_ability = true
	$"../BattleUI".disable_command = true
	$"../BattleUI".disable_item = true
	#$"../EnemyUI".all_enemy_ui()
	#$"../EnemyUI/AllEnemies".show()
	Event.flag_progress("FirstBattle", 3)
	Bt.get_actor("Mira").DontIdle = true
	Bt.end_turn()


func FirstBattle2(target: Actor) -> void:
	await Bt.move(Bt.Troop[0], Vector2(30, 0), 1, Tween.EASE_OUT)
	await Bt.move(Bt.Troop[0], Vector2(20, 0), 1, Tween.EASE_OUT)
	await Event.wait(0.5)
	CurrentChar = Bt.Troop[0]
	target = Bt.Party.Leader
	Bt.CurrentChar = Bt.Troop[0]
	Bt.focus_cam(target, 0.5, 0)
	Bt.zoom(6, 3)
	Bt.anim("Attack1")
	Loader.battle_bars(2)
	Bt.jump_to_target(CurrentChar, target, Vector2(30, 0), 4)
	await Bt.anim_done
	Bt.screen_shake(10)
	Bt.anim("FirstBattle", Bt.Party.Leader)
	CurrentChar.node.hide()
	Bt.play_sound("Attack2", CurrentChar)
	Bt.damage(target, false, false, 12, false)
	Passive.open("story_0", "gahh")
	await Event.wait(2)
	for i in 3:
		Bt.play_sound("Attack2", CurrentChar)
		Bt.damage(target, false, false, randi_range(1, 5), false)
		await Event.wait(0.5)

	await Event.wait(1.8)
	target.Aura = 6
	Hud._check_party()
	Bt.glow(1.5, 0.5, Bt.Party.Leader)
	Bt.zoom(7, 1)
	await Event.wait(4)
	Bt.glow(1, 2, Bt.Party.Leader)
	Passive.open("story_0", "my_aura")
	await Event.wait(6)
	Bt.zoom(5, 3)
	Bt.move_cam(Vector2(-15, 0), 3)
	Bt.anim()
	CurrentChar.node.position.x = 60
	CurrentChar.node.show()
	Bt.move(CurrentChar, Vector2(40, CurrentChar.node.position.y), 0.5)
	await target.node.animation_finished
	target.Abilities[0].disabled = true
	target.DontIdle = false
	Bt.anim("", target)
	$"../BattleUI".disable_ability = false
	$"../BattleUI".disable_attack = true
	CurrentChar.IgnoreStates = true
	await Event.wait(2)
	Event.pop_tutorial("ability")
	Bt.end_turn()


func FirstBattle22() -> void:
	Bt.lock_turn = true
	Event.pop_tutorial("aura1")
	Bt.get_actor("CrawlingSludge").NextAction = Actor.BtAction.MAGIC
	Bt.get_actor("CrawlingSludge").NextMove = load("res://database/Abilities/InnerFocus.tres")


func FirstBattle3() -> void:
	Bt.get_actor("Mira").Abilities[0].disabled = false
	Bt.get_actor("CrawlingSludge").NextAction = Actor.BtAction.MAGIC
	Bt.get_actor("CrawlingSludge").NextMove = load("res://database/Abilities/SoulTap.tres")
	Bt.lock_turn = true
	Event.pop_tutorial("aura2")


func FirstBattle4() -> void:
	$"../BattleUI".disable_attack = false
	Bt.get_actor("Mira").Aura = max(7, Bt.get_actor("Mira").Aura)
	Bt.lock_turn = true
	Event.pop_tutorial("aura3")


func FirstBattle5() -> void:
	Bt.focus_cam(Party.Leader)
	Bt.zoom(6)
	$"../EnemyUI".hide()
	get_tree().paused = false
	Battle.in_battle = false
	Bt.get_actor("Mira").DontIdle = false
	Party.Leader.node.get_node("Glow").hide()
	Loader.battle_bars(0)
	Bt.victory_anim(Party.Leader)
	await Textbox.open("story_0", "what_this")
	Global.heal_party()
	Bt.ObtainedItems.clear()
	Bt.victory(true)


func AlcineWoods1() -> void:
	if Bt.get_actor("Mira").Health == 0: return
	Event.flag_progress("AlcineFollow4", 4)
	Bt.lock_turn = true
	Bt.Action = true
	await Passive.open("story_0", "going_nowhere")
	Event.sequence("AlcineFollowHelp")


func AlcineWoods2() -> void:
	for i in Bt.TurnOrder:
		Bt.anim("Idle", i)

	Global.bt.get_actor("Alcine").node.global_position = Vector2(1660, -1068)
	Bt.focus_cam(Bt.get_actor("Alcine"))
	Bt.get_actor("Alcine").SpeedBoost = +10
	Bt.TurnOrder.sort_custom(Bt.speed_sort)
	Bt.get_actor("Alcine").NextAction = Actor.BtAction.MAGIC
	Bt.get_actor("Alcine").NextMove = load("res://database/Abilities/SoothingSpray.tres")
	Bt.get_actor("Alcine").NextTarget = Bt.get_actor("Mira")
	Bt.get_actor("Alcine").node.show()
	await Event.wait(2)
	Hud.battle_state(true)
	Bt.end_turn()


func AlcineWoods3() -> void:
	await Bt.jump_to_target(Bt.get_actor("Alcine"), Bt.get_actor("Mira"), Vector2(-30, -10), 5)
	await Passive.open("story_0", "amazing")


func ArenaGameOver() -> void:
	Textbox.open("testbush", "arena_over")


func StoneGuardianLoop() -> void:
	if Bt.CurrentChar.codename == "Guardian" and Bt.Turn % 2 == 0 and not Event.f("StoneGuardianFinisher"):
		if CurrentChar.BattleLog.back().ability.filename == "Gather":
			Bt.ignore_end_turn = true
			Bt.CurrentAbility = load("res://database/Abilities/RockThrow.tres")
			await RockThrow(Party.Member1)
			Bt.ignore_end_turn = false
		else:
			Bt.ignore_end_turn = true
			Bt.callout(load("res://database/Abilities/AnythingGoes.tres"))
			await AnythingGoes(Bt.get_actor("Guardian"))
			if not Event.check_flag("StoneGuardianComment"):
				await Event.wait(1)
				await Passive.open("story_0", "anything_goes_comment")
				Event.add_flag("StoneGuardianComment")

			Bt.ignore_end_turn = false

	if Bt.get_actor("Alcine").Health == 0 and Bt.CurrentChar.codename == "Mira" and Event.f("StoneGuardianFinisher"):
		Event.add_flag("BeatStoneGuardian")


func StoneGuardian1() -> void:
	Bt.Party.Leader.ClutchDmg = false
	Bt.Party.Member1.ClutchDmg = false
	var guardian := Bt.get_actor("Guardian")
	Bt.zoom(7, 0)
	guardian.MaterialOverride.set_shader_parameter("new_color", Color(0.235, 0.588, 0.498))
	await Bt.focus_cam(guardian, 0, 0)
	Loader.battle_bars(2)
	guardian.NextMove = await Query.get_ability("SturdyGuard")
	guardian.NextAction = Actor.BtAction.MAGIC
	Bt.zoom(6, 2)
	Bt.focus_cam(guardian, 2, Vector2(-20, -40))
	await Passive.open("story_0", "stone_guardian_intro")
	Bt.entrance_anim(Party.Leader)
	Bt.entrance_anim(Party.Member1)
	await Event.wait(0.2)
	await Bt.focus_cam(Party.Leader)
	Event.remove_flag("StoneGuardianFinisher")
	Event.remove_flag("BeatStoneGuardian")
	Bt.end_turn()


func StoneGuardian2(target: Actor = CurrentChar) -> void:
	if not CurrentChar.codename == "Alcine": return
	Bt.ignore_end_turn = true
	var guardian := Bt.get_actor("Guardian")
	#var mira := Party.Leader
	var alcine := Party.Member1
	Bt.CurrentChar = guardian
	CurrentChar = guardian
	#if mira.Health > 0:
		#await Passive.open("story_0", "stone_guardian_still_standing")

	Bt.callout(load("res://database/Abilities/Adaptation.tres"))
	Bt.zoom(6)
	await Bt.focus_cam(alcine)
	await Bt.focus_cam(guardian, 0.5, 0)
	guardian.remove_state("AuraOverwrite")
	await Bt.aura_overwrite(guardian, Color(0.688, 0.636, 0.0, 1.0), -1)
	#Bt.pop_num(guardian, "Hue-Shift", Color(0.688, 0.636, 0.0, 1.0))
	Global.check.emit()
	await Event.wait(1)
	Bt.get_actor("Guardian").AttackMultiplier = 2
	Bt.get_actor("Guardian").MagicMultiplier = 2
	guardian.NextAction = Actor.BtAction.MAGIC
	guardian.NextMove = load("res://database/Abilities/Drill.tres")
	guardian.MainColor = Color(0.688, 0.636, 0.0, 1.0)

	if alcine.Health > 0:
		guardian.NextTarget = alcine
	else:
		alcine.get_state("KnockedOut").turns = -1

	Event.add_flag("StoneGuardianFinisher")
	Bt.ignore_end_turn = false
	Bt.follow_up_next = false
	Bt.TurnInd = TurnOrder.find(guardian) - 1
	#await Drill(alcine)
	#Bt.next_turn.emit()


func StoneGuardian3() -> void:
	if Party.Member1.Health > 0:
		await Bt.death(Bt.get_actor("Alcine"))

	Bt.ignore_end_turn = true
	Bt.lock_turn = true
	var guardian := Bt.get_actor("Guardian")
	var mira := Party.Leader
	Bt.CurrentChar = guardian
	CurrentChar = guardian
	mira.CantDie = true
	Bt.callout(load("res://database/Abilities/Adaptation.tres"))
	Bt.zoom(6)
	await Bt.focus_cam(mira)
	await Bt.focus_cam(guardian, 0.5, 0)
	guardian.remove_state("AuraOverwrite")
	await Bt.aura_overwrite(guardian, Color(0.498, 0.09, 1.0), -1)
	Bt.pop_num(guardian, "Hue-Shift", Color(0.498, 0.09, 1.0))
	guardian.MainColor = Color(0.498, 0.09, 1.0)
	Global.check.emit()
	await Event.wait(1)
	mira.Aura = 0
	mira.Health = min(mira.Health, 40)
	Bt.callout(load("res://database/Abilities/Drill.tres"))
	await Drill(mira)
	await Event.wait(0.1)
	if mira.has_state("Guarding"):
		mira.remove_state("Guarding")
		await Event.wait(1)
		Passive.open("story_0", "stone_guardian_guard")
		await Event.wait(2)
		mira.Aura = 0
		mira.remove_state("Guarding")
		Bt.outline_remove(mira)
		Bt.anim("Bleed", mira)
		await mira.add_state("AuraBreak")
		await Event.wait(8)
	else:
		Bt.anim("Bleed", mira)
		await mira.add_state("AuraBreak")
		await Event.wait(2)
		await Passive.open("story_0", "stone_guardian_my_arm")

	Bt.follow_up_text()
	Bt.zoom(7)
	await Bt.focus_cam(guardian)
	Bt.zoom(6)
	await Bt.focus_cam(mira, 3)
	await Event.wait(1)
	mira.CantDie = false
	Loader.gray_out(1)
	await Event.wait(1)
	await Textbox.open("story_0", "placeholder_daze")
	Loader.get_node("Can").layer = 3
	Party.set_to(["Mira"])
	Bt.victory(true)
	await Loader.battle_end
	Event.add_flag("BeatStoneGuardian")


func AsteriaBoss2() -> void:
	await Passive.open("story_1", "asteria_boss_2")
	await Bt.add_to_troop(Bt.get_actor("Asteria").SummonedAllies[0])
	await Bt.add_to_troop(Bt.get_actor("Asteria").SummonedAllies[1])
	Bt.position_sprites()
	for i in Bt.Troop: Bt.sprite_init(i)
	Bt.get_actor("Asteria").add_health(90)
	Event.add_flag("AsteriaBoss", 2)


func AsteriaBoss3() -> void:
	var asteria := Bt.get_actor("Asteria")
	Bt.focus_cam(asteria)
	Bt.zoom(6)
	if not Event.f_past("AsteriaBoss", 4):
		await Bt.cut_in("Asteria")
		await Bt.anim("Ability", asteria)
		Loader.white_fadeout(0, 0, 0.5)
		await Event.wait(0.3)
		Bt.anim("", asteria)
		if Bt.has_actor("Bird") or Bt.has_actor("Bird"):
			asteria.Health = asteria.MaxHP

			for i in Bt.Troop:
				match randi_range(0, 3):
					0: i.Health += 20
					1: Bt.stat_change("Mag", 2, i)
					2: Bt.stat_change("Def", 2, i)
					3: Bt.stat_change("Atk", 2, i)
		elif Event.f_past("AsteriaBoss", 3):
			await Textbox.open("story_1", "asteria_boss_4")
			Event.add_flag("AsteriaBoss", 4)
			asteria.Health = asteria.MaxHP
			Bt.stat_change("Atk", 2, asteria, -1)
			Bt.stat_change("Mag", 2, asteria, -1)
			Bt.stat_change("Def", 2, asteria, -1)
			await Event.wait(3)
		elif Event.f_past("AsteriaBoss", 2):
			await Textbox.open("story_1", "asteria_boss_3")
			Event.add_flag("AsteriaBoss", 3)
			asteria.Health = asteria.MaxHP

		Loader.white_fadeout(0.5, 0, 0)
	else:
		Bt.lock_turn = true
		Bt.anim("", asteria)
		await Passive.open("story_1", "asteria_boss_5")
		Event.add_flag("AsteriaBoss", 5)
		Bt.victory()


func AsteriaBossFollowup() -> void:
	await Bt.cut_in("Asteria")
	var asteria := Bt.get_actor("Asteria")
	Bt.focus_cam(asteria)
	Bt.zoom(6)
	await Bt.anim("Ability", asteria)
	Loader.white_fadeout(0, 0, 0.5)
	await Event.wait(0.5)
	if Event.flag_int("AsteriaBoss") < 4:
		for i in Bt.Troop:
			match randi_range(0, 3):
				0: i.Health += 20
				1: Bt.stat_change("Mag", 2, i)
				2: Bt.stat_change("Def", 2, i)
				3: Bt.stat_change("Atk", 2, i)
	else:
		asteria.Health += 15


func nov2_mira_dream() -> void:
	Loader.gray_out(1)
	await Event.wait(0.7)
	Event.to_day = 2
	Event.to_time = 2
	Loader.ungray.emit()
	Event.time_transition()
	Bt.end_battle()


func LazuliteHeartBoss1() -> void:
	var mira := Party.Leader
	Bt.initial = mira.node.position
	CurrentChar = mira
	Bt.anim("Idle", Party.Member1)
	Bt.anim("Idle", Party.Member2)
	Bt.anim("Idle", Party.Member3)
	Bt.zoom(6)
	Bt.focus_cam(Bt.get_actor("LHBody"))
	await Bt.get_actor("LHBody").add_state("UnbreakingAura", -1, mira, false)
	mira.node.position = Bt.get_actor("LHRight").node.position
	Loader.battle_bars(2)
	await Passive.open("story_2", "lazulite_heart_intro")
	#Bt.return_cur(mira)
	mira.NextAction = Actor.BtAction.ACT
	mira.NextMove = Ability.nothing()
	var alcine := Bt.get_actor("Alcine")
	alcine.NextAction = Actor.BtAction.ACT
	alcine.NextMove = Bt.get_actor("Alcine").StandardAttack
	alcine.NextTarget = Bt.get_actor("LHRight")
	Bt.no_misses = true
	Bt.end_turn()


func LazuliteHeartBoss2() -> void:
	await Textbox.open("story_2", "lazulite_heart_3")
	Loader.gray_out(1, 0.5, 1, Color.WHITE)
	await Event.wait(1)
	Bt.victory(true)
#endregion
