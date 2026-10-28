extends Node

@onready var Bt: Battle = get_parent()
var Char: Actor
signal ai_chosen


func ai() -> void:
	print("AI")
	Char = Bt.CurrentChar

	if Char.has_state("KnockedOut") or Char.health == 0:
		print("Cannot move, skip turn")
		Char.next_action = Actor.BtAction.ACT
		choose(Ability.nothing())
		return

	if Char.next_action != Actor.BtAction.UNSET:
		print("Forced move")
		choose(Char.next_move, Char.next_target)
		return

	var best_ability: Ability = null
	var best_target: Actor = null
	var highest_score: float = -1.0

	var available_abilities: Array[Ability] = Char.abilities.duplicate()

	if Char.standard_attack: available_abilities.append(Char.standard_attack)

	print("Available options:")

	for ability in available_abilities:
		if not is_instance_valid(ability):
			push_error("AI found an invalid ability")
			continue

		print("-> %s" % [ability.name])
		if ability.aura_cost != 0: print(" - Cost: %d AP" % [ability.aura_cost])
		if not can_afford(ability):
			print("	Can't afford")

			continue

		var valid_targets := get_valid_targets(ability)
		var score_modifier := get_ability_score_modifiers(ability)

		if ability.is_aoe():
			# For AOE Abilities, scores are added up, then devided by the number of targets
			var score := 0.0

			for target in valid_targets:
				score += evaluate_action(ability, target)

			score += score_modifier
			score /= valid_targets.size()

			# Discourage AOE attacks on single targets
			if valid_targets.size() == 1:
				score -= 0.3

			# Add slight variance
			score += randf_range(-0.1, 0.1)

			print("	%d AOE targets = %.2f" % [valid_targets.size(), score])

			if score > highest_score:
				highest_score = score
				best_ability = ability
				best_target = Char
		else:
			# For single target, every combo gets its own score
			for target in valid_targets:
				var score := evaluate_action(ability, target)
				score += score_modifier

				# Add slight variance
				score += randf_range(-0.15, 0.15)

				print("	%s = %.2f" % [target.first_name, score])

				if score > highest_score:
					highest_score = score
					best_ability = ability
					best_target = target

	print("--------")

	if best_ability == null:
		print("Nothing else to do, using Standard Attack")
		best_ability = Char.standard_attack
		best_target = Bt.random_target(best_ability)

	choose(best_ability, best_target)


## Adds a score for the usefulness of this ability as each type
func evaluate_action(ab: Ability, tar: Actor) -> float:
	var score := 0.1

	for type in ab.types:
		match type:
			Ability.TP.HEALING:
				if is_ally(tar):
					var hp_pct := tar.health_ratio()
					# Scales up as HP gets lower
					if hp_pct <= 0.9:
						score += (1.1 - hp_pct)

			Ability.TP.SUMMON:
				if Bt.get_ally_faction(Char).size() < 3:
					score += 0.2

				if Bt.get_ally_faction(Char).size() == 1:
					score += 0.3

			Ability.TP.CHEAP_ATTACK:
				if is_enemy(tar):
					# Prioritize an attack that will finish off the enemy
					if tar.health <= (Char.weapon.power * Char.get_attack() * tar.get_defence()):
						score = 1
					else:
						score += 0.5

					# More likely to use if there's a buff
					if ab.is_magic() and Char.has_state("MagUp"):
						score += 0.3
					elif Char.has_state("AtkUp"):
						score += 0.3

			Ability.TP.BIG_ATTACK:
				if is_enemy(tar):
					score += 0.7
					# More likely to use if there's a buff, more so that a cheap attack
					if ab.is_magic() and Char.has_state("MagUp"):
						score += 0.5
					elif Char.has_state("AtkUp"):
						score += 0.5

			Ability.TP.CURSE:
				if is_enemy(tar):
					var crit_mult: float = ab.crit_chance if ab.crit_chance > 0 else 1.0

					if not tar.has_state(str(ab.inflicts_state())): score += 0.75 * crit_mult
			Ability.TP.ATK_BUFF:
				if is_ally(tar):
					if tar.attack_multiplier <= 1.0:
						score += 0.2

					if tar.actor_class == "Attacker":
						score += 0.4

			Ability.TP.MAG_BUFF:
				if is_ally(tar):
					if tar.magic_multiplier <= 1.0:
						score += 0.2

					if tar.actor_class == "Mage":
						score += 0.4

			Ability.TP.DEF_BUFF:
				if is_ally(tar):
					if tar.defence_multiplier <= 1.0:
						score += 0.2

					if tar.actor_class == "Tank":
						score += 0.4

			Ability.TP.AGGRO:
				if is_enemy(tar):
					if tar.get_attack() > 1:
						score += 0.5

			Ability.TP.DEFENSIVE:
				if Char.health < Char.max_hp * 0.6:
					score += 0.3

				if Char.aura < Char.max_aura * 0.6:
					score += 0.4

				if Char.aura < Char.max_aura * 0.2:
					score += 0.5

			_:
				# Just keep a high enough chance on unkown type things
				score = max(score, 0.5)

	return score


func get_ability_score_modifiers(ab: Ability) -> float:
	var score := 0.0

	# Penalize high costs
	var total_cost: float = (ab.aura_cost + (ab.hp_cost / 2))

	if total_cost > 0:
		var penalty: float = (total_cost / float(Char.aura)) * 0.3
		score -= penalty
		print(" - Cost penalty: -%.2f" % [penalty])

	# More likely to use aura recovery when low on AP
	if ab.recover_aura and not Char.aura == Char.max_aura:
		var bonus: float = (1 - Char.aura_ratio()) / 2
		score += bonus
		print(" - Recovery bonus: +%.2f" % [bonus])

	# Discourage spamming the same thing
	if Char.battle_log.back().ability == ab:
		score -= 0.3
		print(" - Avoid using the same thing again: -0.3")

	return score


func can_afford(ab: Ability) -> bool:
	# Can't attack when bound
	if Char.has_state("Bound") and ab.uses_weapon(): return false
	# Can't use magic when deflected
	if Char.has_state("Deflected") and ab.wheel_color != Color.WHITE: return false
	# Handle cost
	if ab.aura_cost != 0 and ab.aura_cost > Char.aura: return false
	if ab.hp_cost > Char.health: return false
	return true


func get_valid_targets(ab: Ability) -> Array[Actor]:
	var targets: Array[Actor] = []

	match ab.target:
		Ability.T.SELF:
			targets.append(Char)

		Ability.T.ONE_ALLY, Ability.T.AOE_ALLIES:
			targets.append_array(Bt.get_ally_faction(Char, not ab.can_target_dead))

		Ability.T.ONE_ENEMY, Ability.T.AOE_ENEMIES:
			targets.append_array(Bt.get_opposing_faction(Char, not ab.can_target_dead))

		Ability.T.ANY:
			targets.append_array(Bt.TurnOrder)

	return targets


func is_ally(tar: Actor) -> bool:
	return Char.is_enemy == tar.is_enemy


func is_enemy(tar: Actor) -> bool:
	return not is_ally(tar)


func choose(ab: Ability, tar: Actor = null) -> void:
	if ab == null:
		Bt.end_turn()
		return

	if ab.target == Ability.T.SELF:
		tar = Char
	elif Char.next_target == null:

		if tar == null:
			Char.next_target = Bt.random_target(ab)

		Char.next_target = tar

	if Char.next_action == Actor.BtAction.UNSET:
		if ab in Char.abilities:
			Char.next_action = Actor.BtAction.MAGIC
		else:
			Char.next_action = Actor.BtAction.ACT

		Char.next_move = ab

	if (Char.has_state("Confused") and not ab.is_aoe()):
		Char.next_target = Bt.TurnOrder.pick_random()
		Bt.confusion_msg()

	ai_chosen.emit()
