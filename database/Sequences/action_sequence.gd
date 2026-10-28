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
func FirstBattle1() -> void:
	Bt.no_misses = true
	Bt.no_crits = true
	Global.player.position = Vector2(1470, 400)
	await Event.wait(1, false)
	Global.camera.enabled = false
	Bt.Troop[0].node.position.x = 50
	Bt.focus_cam(Bt.Troop[0], 0.1, 0)
	Bt.zoom(6)
	Bt.Action = true
	Battle.in_battle = true
	Loader.battle_bars(4)
	Global.player.hide()
	await Event.wait(0.5, false)
	Transition.fade_out()
	await Event.wait(0.3, false)
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
	Bt.ui.disable_ability = true
	Bt.ui.disable_command = true
	Bt.ui.disable_item = true
	Event.flag_progress("Event/FirstBattle", 3)
	Bt.get_actor("Mira").dont_idle = true
	Bt.end_turn()


func FirstBattle2(target: Actor) -> void:
	await Bt.move(Bt.Troop[0], Vector2(30, 0), 1, Tween.EASE_OUT)
	await Bt.move(Bt.Troop[0], Vector2(20, 0), 1, Tween.EASE_OUT)
	await Event.wait(0.5)
	CurrentChar = Bt.Troop[0]
	target = Party.Leader
	Bt.CurrentChar = Bt.Troop[0]
	Bt.focus_cam(target, 0.5, 0)
	Bt.zoom(6, 3)
	Bt.anim("Attack1")
	Loader.battle_bars(2)
	Bt.jump_to_target(CurrentChar, target, Vector2(30, 0), 4)
	await Bt.anim_done
	Bt.screen_shake(10)
	Bt.anim("FirstBattle", Party.Leader)
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
	target.aura = 6
	Hud._check_party()
	Bt.glow(1.5, 0.5, Party.Leader)
	Bt.zoom(7, 1)
	await Event.wait(4)
	Bt.glow(1, 2, Party.Leader)
	Passive.open("story_0", "my_aura")
	await Event.wait(6)
	Bt.zoom(5, 3)
	Bt.move_cam(Vector2(-15, 0), 3)
	Bt.anim()
	CurrentChar.node.position.x = 60
	CurrentChar.node.show()
	Bt.move(CurrentChar, Vector2(40, CurrentChar.node.position.y), 0.5)
	await Bt.await_anim(target.node)
	target.abilities[0].disabled = true
	target.dont_idle = false
	Bt.anim("", target)
	Bt.ui.disable_ability = false
	Bt.ui.disable_attack = true
	CurrentChar.ignore_states = true
	await Event.wait(2)
	Event.pop_tutorial("ability")
	Bt.end_turn()


func FirstBattle22() -> void:
	Bt.hold_turn()
	Event.pop_tutorial("aura1")
	Bt.get_actor("CrawlingSludge").next_action = Actor.BtAction.MAGIC
	Bt.get_actor("CrawlingSludge").next_move = load("res://database/Abilities/InnerFocus.tres")


func FirstBattle3() -> void:
	Bt.get_actor("Mira").abilities[0].disabled = false
	Bt.get_actor("CrawlingSludge").next_action = Actor.BtAction.MAGIC
	Bt.get_actor("CrawlingSludge").next_move = load("res://database/Abilities/SoulTap.tres")
	Bt.hold_turn()
	Event.pop_tutorial("aura2")


func FirstBattle4() -> void:
	Bt.ui.disable_attack = false
	Bt.get_actor("Mira").aura = max(7, Bt.get_actor("Mira").aura)
	Bt.hold_turn()
	Event.pop_tutorial("aura3")


func FirstBattle5() -> void:
	Bt.focus_cam(Party.Leader)
	Bt.zoom(6)
	Bt.enemy_ui.hide()
	get_tree().paused = false
	Battle.in_battle = false
	Bt.get_actor("Mira").dont_idle = false
	Party.Leader.node.get_node("Glow").hide()
	Loader.battle_bars(0)
	Bt.victory_anim(Party.Leader)
	Bt.victory_music()
	await Textbox.open("story_0", "what_this")
	Party.heal_party()
	Bt.ObtainedItems.clear()
	Bt.victory(true)


func AlcineWoods1() -> void:
	if Bt.get_actor("Mira").health == 0: return
	Event.flag_progress("Event/AlcineFollow", 4)
	Bt.hold_turn()
	Bt.Action = true
	await Passive.open("story_0", "going_nowhere")
	Event.run_cue("story_0", "AlcineFollowHelp")


func AlcineWoods2() -> void:
	for i in Bt.TurnOrder:
		Bt.anim("Idle", i)

	Global.bt.get_actor("Alcine").node.global_position = Vector2(1660, -1068)
	Bt.focus_cam(Bt.get_actor("Alcine"))
	Bt.get_actor("Alcine").speed_boost = +10
	Bt.TurnOrder.sort_custom(Bt.speed_sort)
	Bt.get_actor("Alcine").next_action = Actor.BtAction.MAGIC
	Bt.get_actor("Alcine").next_move = load("res://database/Abilities/SoothingSpray.tres")
	Bt.get_actor("Alcine").next_target = Bt.get_actor("Mira")
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
	if Bt.CurrentChar.codename == "Guardian" and Bt.Turn % 2 == 0 and not Event.check_flag("Event/StoneGuardianFinisher"):
		if CurrentChar.battle_log.back().ability.filename == "Gather":
			var rock_throw: Ability = load("res://database/Abilities/RockThrow.tres")
			await Bt.use_ability_now(CurrentChar, rock_throw, Party.Member1)
		else:
			var anything_goes: Ability = load("res://database/Abilities/AnythingGoes.tres")
			Bt.callout(anything_goes)
			await Bt.use_ability_now(CurrentChar, anything_goes, Bt.get_actor("Guardian"))
			if not Event.check_flag("Event/StoneGuardianComment"):
				await Event.wait(1)
				await Passive.open("story_0", "anything_goes_comment")
				Event.add_flag("Event/StoneGuardianComment")

	if Bt.get_actor("Alcine").health == 0 and Bt.CurrentChar.codename == "Mira" and Event.check_flag("Event/StoneGuardianFinisher"):
		Event.add_flag("Event/BeatStoneGuardian")


func StoneGuardian1() -> void:
	Party.Leader.clutch_dmg = false
	Party.Member1.clutch_dmg = false
	var guardian := Bt.get_actor("Guardian")
	Bt.zoom(7, 0)
	guardian.material_override.set_shader_parameter("new_color", Color(0.235, 0.588, 0.498))
	await Bt.focus_cam(guardian, 0, 0)
	Loader.battle_bars(2)
	guardian.next_move = await Query.get_ability("SturdyGuard")
	guardian.next_action = Actor.BtAction.MAGIC
	Bt.zoom(6, 2)
	Bt.focus_cam(guardian, 2, Vector2(-20, -40))
	await Passive.open("story_0", "stone_guardian_intro")
	Bt.entrance_anim(Party.Leader)
	Bt.entrance_anim(Party.Member1)
	await Event.wait(0.2)
	await Bt.focus_cam(Party.Leader)
	Event.remove_flag("Event/StoneGuardianFinisher")
	Event.remove_flag("Event/BeatStoneGuardian")
	Bt.end_turn()


func StoneGuardian2(target: Actor = CurrentChar) -> void:
	if not CurrentChar.codename == "Alcine": return
	var guardian := Bt.get_actor("Guardian")
	#var mira := Party.Leader
	var alcine := Party.Member1
	Bt.CurrentChar = guardian
	CurrentChar = guardian
	#if mira.health > 0:
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
	Bt.get_actor("Guardian").attack_multiplier = 2
	Bt.get_actor("Guardian").magic_multiplier = 2
	guardian.next_action = Actor.BtAction.MAGIC
	guardian.next_move = load("res://database/Abilities/Drill.tres")
	guardian.main_color = Color(0.688, 0.636, 0.0, 1.0)

	if alcine.health > 0:
		guardian.next_target = alcine
	else:
		alcine.get_state("KnockedOut").turns = -1

	Event.add_flag("Event/StoneGuardianFinisher")
	Bt.follow_up_next = false
	Bt.TurnInd = TurnOrder.find(guardian) - 1
	#await Drill(alcine)
	#Bt.next_turn.emit()


func StoneGuardian3() -> void:
	if Party.Member1.health > 0:
		await Bt.death(Bt.get_actor("Alcine"))

	Bt.hold_turn()
	var guardian := Bt.get_actor("Guardian")
	var mira := Party.Leader
	Bt.CurrentChar = guardian
	CurrentChar = guardian
	mira.cant_die = true
	Bt.callout(load("res://database/Abilities/Adaptation.tres"))
	Bt.zoom(6)
	await Bt.focus_cam(mira)
	await Bt.focus_cam(guardian, 0.5, 0)
	guardian.remove_state("AuraOverwrite")
	await Bt.aura_overwrite(guardian, Color(0.498, 0.09, 1.0), -1)
	Bt.pop_num(guardian, "Hue-Shift", Color(0.498, 0.09, 1.0))
	guardian.main_color = Color(0.498, 0.09, 1.0)
	Global.check.emit()
	await Event.wait(1)
	mira.aura = 0
	mira.health = min(mira.health, 40)
	var drill: Ability = load("res://database/Abilities/Drill.tres")
	Bt.callout(drill)
	await Bt.use_ability_now(CurrentChar, drill, mira)
	await Event.wait(0.1)
	if mira.has_state("Guarding"):
		mira.remove_state("Guarding")
		await Event.wait(1)
		Passive.open("story_0", "stone_guardian_guard")
		await Event.wait(2)
		mira.aura = 0
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
	mira.cant_die = false
	Transition.fade_in()
	await Event.wait(1)
	await Textbox.open("story_0", "placeholder_daze")
	Loader.get_node("Can").layer = 3
	Party.set_to(["Mira"])
	Bt.victory(true)
	await Global.battle_end
	Event.add_flag("Event/BeatStoneGuardian")


func ColorTutorialEnter() -> void:
	Bt.anim("Command", Party.Leader)
	Bt.anim("Hit", Party.Member1)
	Bt.zoom(6)
	Bt.focus_cam(Party.Leader)


func AsteriaBoss2() -> void:
	await Passive.open("story_1", "asteria_boss_2")
	await Bt.add_to_troop(Bt.get_actor("Asteria").summoned_allies[0])
	await Bt.add_to_troop(Bt.get_actor("Asteria").summoned_allies[1])
	Bt.position_sprites()
	for i in Bt.Troop: Bt.sprite_init(i)
	Bt.get_actor("Asteria").add_health(90)
	Event.add_flag("Event/AsteriaBoss", 2)


func AsteriaBoss3() -> void:
	var asteria := Bt.get_actor("Asteria")
	Bt.focus_cam(asteria)
	Bt.zoom(6)
	if not Event.f_past("Event/AsteriaBoss", 4):
		await Bt.cut_in("Asteria")
		await Bt.anim("Ability", asteria)
		Transition.fade_in_out(Color.WHITE, 0.5, 0)
		await Event.wait(0.3)
		Bt.anim("", asteria)
		if Bt.has_actor("Bird") or Bt.has_actor("Bird"):
			asteria.health = asteria.max_hp

			for i in Bt.Troop:
				match randi_range(0, 3):
					0: i.health += 20
					1: Bt.stat_change("Mag", 2, i)
					2: Bt.stat_change("Def", 2, i)
					3: Bt.stat_change("Atk", 2, i)
		elif Event.f_past("Event/AsteriaBoss", 3):
			await Textbox.open("story_1", "asteria_boss_4")
			Event.add_flag("Event/AsteriaBoss", 4)
			asteria.health = asteria.max_hp
			Bt.stat_change("Atk", 2, asteria, -1)
			Bt.stat_change("Mag", 2, asteria, -1)
			Bt.stat_change("Def", 2, asteria, -1)
			await Event.wait(3)
		elif Event.f_past("Event/AsteriaBoss", 2):
			await Textbox.open("story_1", "asteria_boss_3")
			Event.add_flag("Event/AsteriaBoss", 3)
			asteria.health = asteria.max_hp

		Transition.fade_in_out(Color.WHITE, 0.5, 0, 0)
	else:
		Bt.hold_turn()
		Bt.anim("", asteria)
		await Passive.open("story_1", "asteria_boss_5")
		Event.add_flag("Event/AsteriaBoss", 5)
		Bt.victory()


func AsteriaBossFollowup() -> void:
	await Bt.cut_in("Asteria")
	var asteria := Bt.get_actor("Asteria")
	Bt.focus_cam(asteria)
	Bt.zoom(6)
	await Bt.anim("Ability", asteria)
	Transition.fade_in_out(Color.WHITE, 0.5, 0, 0)
	await Event.wait(0.5)
	if Event.get_flag("Event/AsteriaBoss") < 4:
		for i in Bt.Troop:
			match randi_range(0, 3):
				0: i.health += 20
				1: Bt.stat_change("Mag", 2, i)
				2: Bt.stat_change("Def", 2, i)
				3: Bt.stat_change("Atk", 2, i)
	else:
		asteria.health += 15


func nov2_mira_dream() -> void:
	Transition.fade_in()
	await Event.wait(0.7)
	Event.to_day = 2
	Event.to_time = 2
	Transition.fade_out()
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
	mira.next_action = Actor.BtAction.ACT
	mira.next_move = Ability.nothing()
	var alcine := Bt.get_actor("Alcine")
	alcine.next_action = Actor.BtAction.ACT
	alcine.next_move = Bt.get_actor("Alcine").standard_attack
	alcine.next_target = Bt.get_actor("LHRight")
	Bt.no_misses = true
	Bt.end_turn()


func LazuliteHeartBoss2() -> void:
	await Textbox.open("story_2", "lazulite_heart_3")
	await Transition.fade_in(Color.WHITE, 1)
	Bt.victory(true)
#endregion
