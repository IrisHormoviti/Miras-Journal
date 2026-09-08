extends Node2D
class_name Battle

## Is the player currently in a battle?
static var in_battle: bool:
	get(): return is_instance_valid(current)
## The current battle instance
static var current: Battle
## Battle sequence of the current battle
static var sequence: BattleSequence
static var prevent_battles: bool = false
static var remembered_camera_zoom: Vector2
static var battle_advantage := 0
static var attacker: NPC = null

enum Result {UNFINISHED, VICTORY, ESCAPE, DEFEAT}
static var battle_result: Result = Result.UNFINISHED

## Used for battle messages
@export var BattleText: Dictionary[String, String]
## Array of the enemies of this battle.
## Enemies can be added or removed throughout
var Troop: Array[Actor]
## All actors in this battle, ordered by their speed
var TurnOrder: Array[Actor]
## The current turn
var Turn: int = 0
## Index of the current actor in the turn order
var TurnInd: int = -1
## The character whoose turn it is
var CurrentChar: Actor
## Currently targeted actor
var CurrentTarget: Actor
## The ability currently being used
var CurrentAbility: Ability
## If the player is currently selecting something (false)
## Or they're watching things happen (true)
var Action: bool
## True after the victory screen is shown,
## and is waiting for the player to continue
var AwaitVictory := false
## Used for the SP counting in the victory screen
var count_sp: int
## SP that will be earned after winning
var totalSP: int = 0
## Items to be earned after winning
var ObtainedItems: Array[ItemData] = []
## The position of the CurrentChar at the start of this turn
var initial: Vector2
## Is the callout text on screen
var callout_onscreen := false
## The turn will not end when requested, but will once this is false
var lock_turn := false
## The turn will not end when requested
var ignore_end_turn := false
## Prevent critical hits
var no_crits := false
## Prevent missing
var no_misses := false
## The next turn a followup will be preformed
var follow_up_next := false
## Counts turn ends for each AOE ability sequence
## The turn ends after all targets have returned
var aoe_returns := 0

@onready var ui: Control = %ControllerBattleUI
@onready var canvas: CanvasLayer = $Canvas
@onready var enemy_ui: CanvasLayer = $EnemyUI
@onready var act: Node2D = $Act
@onready var cam: Camera2D = $Act/Cam
@onready var effects: AnimatedSprite2D = $Act/Effects

signal battle_start
signal battle_end(result: int)
signal GetControl
signal next_turn
signal check_party
signal anim_done
signal take_dmg


##Starts the specified battle. Advantage: 0 for Neutual, 1 for Player, 2 for enemy
static func start(stg: Variant, advantage := 0) -> void:
	if in_battle:
		return

	if stg is String:
		sequence = await Loader.load_res("res://database/BattleSeq/" + stg + ".tres")
	elif stg is BattleSequence:
		sequence = stg
	else:
		Global.toast("The battle sequence isn't set here, you probably should fix this.")
		await Event.wait(0.3)
		Event.give_control()
		Hud.show_all()
		return

	if prevent_battles:
		return

	battle_result = Result.UNFINISHED
	Hud.ui_visible = false
	#Engine.time_scale = 0.1
	Hud.hide_all()
	Global.controllable = false
	print_rich("[color=green]Battle start!")
	Global.get_tree().paused = true
	remembered_camera_zoom = Global.camera.zoom

	if sequence.Transition:
		if is_instance_valid(attacker):
			if sequence.Music:
				Audio.change_music_from_to(sequence.Music.track, 0, sequence.Music.intro_end)

			Loader.battle_bars(2, 0.8, Tween.EASE_OUT)
			tween(Global.camera, "zoom", Vector2(6, 6), 1, Tween.EASE_OUT, Tween.TRANS_CUBIC)
			#if advantage == 1: t.tween_property(Camera, "global_position", Attacker.global_position, 0.4)
			await Event.wait(0.8, false)

		tween(Global.camera, "zoom", Vector2(8, 8), 0.5, Tween.EASE_IN, Tween.TRANS_CUBIC)
		await Loader.battle_bars(4, 0.5, Tween.EASE_IN)

	#Engine.time_scale = 1
	var battle: Node = (await Loader.load_res("uid://chjrhe4gw1iu6")).instantiate()

	if is_instance_valid(Global.player):
		Global.player.hide()
		if not sequence.UseBackground:
			Global.player.position = sequence.ScenePosition
		elif sequence.ScenePosition == Vector2.ZERO:
			sequence.ScenePosition = Global.room.battleback_position

		Global.player.get_node("DirectionMarker/Finder/Shape").set_deferred("disabled", true)
		Global.player.camera_follow(false)

	if not sequence.PartyOverride.is_empty():
		Party.set_to(sequence.PartyOverride)

	Global.camera.position_smoothing_enabled = false
	Global.get_tree().root.add_child(battle)
	if is_instance_valid(attacker):
		attacker.hide()

	for i in Global.room.followers:
		if is_instance_valid(i) and is_instance_valid(Global.player):
			i.hide()
			i.global_position = Global.player.position


func _ready() -> void:
	battle_start.emit()
	current = self
	get_tree().paused = false
	Global.controllable = false
	cam.make_current()
	Action = true
	TurnInd = -1
	Turn = 0

	if Party.Leader == null:
		end_battle()
		return

	CurrentChar = Party.Leader
	CurrentAbility = Party.Leader.StandardAttack

	if sequence == null:
		sequence = load("res://database/BattleSeq/DebugDummy.tres")

	sequence.reset_events(true)

	for i in sequence.Enemies:
		Troop.append(i.duplicate())

	Party.Leader.node = act.get_node("Actor0")
	TurnOrder.push_front(Party.Leader)
	TurnOrder.append_array(Troop)
	$Background.texture = sequence.BattleBack

	if sequence.BattleBack == null:
		act.get_node("Actor0").light_mask = 1

	if sequence.PositionSameAsPlayer:
		sequence.ScenePosition = Global.player.global_position + Vector2(45, 0)

	if Global.camera != null:
		cam.global_position = Global.camera.global_position
		cam.zoom = Global.camera.zoom

	$Canvas/Cutin.hide()
	act.get_node("Actor0").sprite_frames = await Party.Leader.get_BT()
	act.get_node("Actor0").animation = &"Entrance"
	act.get_node("Actor0").frame = 0
	act.get_node("Actor0/Shadow").modulate = Color.WHITE
	$Canvas/VictoryText.modulate = Color.TRANSPARENT
	$Canvas/SPGain.hide()
	$Canvas/VictoryItems.hide()
	if Global.room: Global.room.show()
	for i in range(1, 4):
		if Party.has_member_index(i):
			var member := Party.current[i]
			var dub := act.get_node("Actor0").duplicate()
			dub.name = "Actor" + str(i)
			act.add_child(dub)
			member.node = dub
			dub.sprite_frames = await member.get_BT()
			TurnOrder.push_front(member)
			dub.material = dub.material.duplicate()

			if member.SoundSet:
				dub.add_child(member.SoundSet.instantiate())

	for i in Party.current:
		if not i: continue
		match Party.current.find(i):
			0: i.Speed = 8
			1: i.Speed = 6
			2: i.Speed = 4
			3: i.Speed = 2

		i.IsEnemy = false

	for i in Troop.size():
		var dub := act.get_node("Actor0").duplicate()
		dub.name = "Enemy" + str(i)
		act.add_child(dub)
		Troop[i].node = dub
		dub.sprite_frames = await Troop[i].get_BT()
		dub.material = dub.material.duplicate()
		dub.offset = Troop[i].Offset
		dub.play("Idle")
		Troop[i].Health = Troop[i].MaxHP
		Troop[i].Aura = Troop[i].MaxAura
		dub.add_child(Troop[i].SoundSet.instantiate())

	if battle_advantage == 1:
		for i in TurnOrder:
			if not i.IsEnemy: i.SpeedBoost += 5
	elif battle_advantage == 2:

		for i in TurnOrder:
			if i.IsEnemy: i.SpeedBoost += 10

	act.get_node("Actor0").add_child(Party.Leader.SoundSet.instantiate())
	for i in TurnOrder:
		sprite_init(i)
		i.NextAction = Actor.BtAction.UNSET
		i.BattleLog = [Actor.log_entry.new()]
		i.load_complimentaries()

	if sequence.Music:
		Audio.change_music_from_to(sequence.Music.track, sequence.Music.battle_start)

	
	position_sprites()
	if is_instance_valid(attacker): attacker.hide()
	if sequence.EntranceSequence != "": await act.call(sequence.EntranceSequence)
	TurnOrder.sort_custom(speed_sort)
	turn_ui_init()
	for i in TurnOrder:
		print(i.Speed + i.SpeedBoost, " - ", i.FirstName)

	
	act.reparent(get_node(Loader.area_spawn_path))
	act.global_position = sequence.ScenePosition
	act.z_index = Global.room.camera_index.z
	cam.make_current()
	
	await entrance()


static func tween(
	object: Node,
	property: String,
	to: Variant,
	time := 0.3,
	ease_type := Tween.EASE_OUT,
	trans := Tween.TRANS_CUBIC
) -> void:
	var t := Global.create_tween()
	t.set_ease(ease_type)
	t.set_trans(trans)
	t.tween_property(object, NodePath(property), to, time)
	await t.finished


func sprite_init(i: Actor) -> void:
	i.node.sprite_frames = await i.get_BT()
	i.node.flip_h = i.FlipH
	i.node.get_node("State").play("None")
	if not i.Shadow:
		i.node.get_child(0).hide()

	if i.IsEnemy: i.node.get_node("Glow").energy = i.GlowDef
	else:
		var t := create_tween()
		t.tween_property(i.node.get_node("Glow"), "energy", i.GlowDef, 1)

	i.node.get_node("Glow").color = i.MainColor

	if i.MaterialOverride != null:
		i.node.material = i.MaterialOverride


func speed_sort(a: Actor, b: Actor) -> bool:
	if a.Speed + a.SpeedBoost > b.Speed + b.SpeedBoost:
		return true
	elif a.Speed + a.SpeedBoost == b.Speed + b.SpeedBoost:

		if a.IsEnemy:
			return false
		else:
			return true
	else:
		return false


func turn_ui_init() -> void:
	var entr: Control = $Canvas/TurnOrderPop/Margin/List.get_child(0).duplicate()

	for i in $Canvas/TurnOrderPop/Margin/List.get_children(): i.queue_free()
	for i in TurnOrder:
		entr = entr.duplicate()
		entr.get_node("Icon").texture = i.PartyIcon
		entr.get_node("Name").text = i.FirstName
		entr.set_meta("Actor", i)
		$Canvas/TurnOrderPop/Margin/List.add_child(entr)

	if $Canvas/TurnOrderPop/Margin/List.get_child(0).name == "Char":
		$Canvas/TurnOrderPop/Margin/List/Char.queue_free()


func turn_ui_check() -> void:
	for i in $Canvas/TurnOrderPop/Margin/List.get_children():
		if i.get_meta("Actor") == CurrentChar: i.get_node("Arrow").show()
		else: i.get_node("Arrow").hide()


func position_sprites() -> void:
	act.get_node("Actor0").show()
	
	match Query.number_of_party_members():
		1:
			Party.Leader.node.position = Vector2(-45, 0)

		2:
			Party.Leader.node.position = Vector2(-45, -15)
			Party.current[1].node.show()
			Party.current[1].node.position = Vector2(-45, 45)

		3:
			Party.Leader.node.position = Vector2(-45, -25)
			Party.current[1].node.show()
			Party.current[1].node.position = Vector2(-45, 15)
			Party.current[2].node.show()
			Party.current[2].node.position = Vector2(-45, 55)

		4:
			Party.Leader.node.position = Vector2(-20, -40)
			Party.current[1].node.show()
			Party.current[1].node.position = Vector2(-45, -15)
			Party.current[2].node.show()
			Party.current[2].node.position = Vector2(-20, 15)
			Party.current[3].node.show()
			Party.current[3].node.position = Vector2(-45, 40)

	match Troop.size():
		1:
			act.get_node("Enemy0").show()
			act.get_node("Enemy0").position = Vector2(66, 0)

		2:
			if act.has_node("Enemy0"):
				act.get_node("Enemy0").show()
				act.get_node("Enemy0").position = Vector2(66, -15)

			if act.has_node("Enemy1"):
				act.get_node("Enemy1").show()
				act.get_node("Enemy1").position = Vector2(46, 30)

		3:
			if act.has_node("Enemy0"):
				act.get_node("Enemy0").show()
				act.get_node("Enemy0").position = Vector2(66, -25)

			if act.has_node("Enemy1"):
				act.get_node("Enemy1").show()
				act.get_node("Enemy1").position = Vector2(36, 15)

			if act.has_node("Enemy2"):
				act.get_node("Enemy2").show()
				act.get_node("Enemy2").position = Vector2(66, 55)

		4:
			if act.has_node("Enemy0"):
				act.get_node("Enemy0").show()
				act.get_node("Enemy0").position = Vector2(66, -35)

			if act.has_node("Enemy1"):
				act.get_node("Enemy1").show()
				act.get_node("Enemy1").position = Vector2(36, 15)

			if act.has_node("Enemy2"):
				act.get_node("Enemy2").show()
				act.get_node("Enemy2").position = Vector2(90, 15)

			if act.has_node("Enemy3"):
				act.get_node("Enemy3").show()
				act.get_node("Enemy3").position = Vector2(66, 65)

	for i in TurnOrder:
		if i.CustomPosition != Vector2i.ZERO:
			i.node.position = i.CustomPosition

		pixel_perfectize(i)


func entrance() -> void:
	Action = true
	Global.controllable = false
	cam.position_smoothing_enabled = false

	if sequence.Transition:
		Loader.battle_bars(3)
		if sequence.EntranceBanter != "":
			if sequence.EntranceBanterIsPassive:
				Passive.open("banter_entrance", sequence.EntranceBanter)
			else:
				Textbox.open("banter_entrance", sequence.EntranceBanter)
				cam.position.x = 60

				while Textbox.is_open:
					if cam.position.x > 0: cam.position.x -= 0.01
					await Event.wait()

		if sequence.EntranceSequence == "":
			cam.zoom = Vector2(4, 4)
			cam.position = Vector2(90, 10)
			var t := create_tween()
			t.set_ease(Tween.EASE_IN_OUT)
			t.set_trans(Tween.TRANS_QUART)
			t.tween_property(cam, "zoom", Vector2(5.5, 5.5), 0.5)
			t.parallel().tween_property(cam, "position", Vector2(90, 0), 0.5)
			t.tween_property(cam, "position", Vector2(-50, 0), 0.5).set_delay(0.5)
			await Event.wait(0.3, false)
			enemy_ui.all_enemy_ui(true)
			if battle_advantage == 1:
				for i in Troop: damage(i, 1, false, 24 / Troop.size())

			await Event.wait(0.5, false)

	if sequence.EntranceSequence == "":
		for i in Party.current:
			if not i: continue
			entrance_anim(i)

	Loader.battle_bars(2)
	await Event.wait(0.5, false)
	if not sequence.Transition: enemy_ui.all_enemy_ui(true)
	Hud.battle_state(true)
	Hud.save_box_positions()
	await Event.wait(0.7, false)
	if sequence.EntranceSequence == "": next_turn.emit()


func entrance_anim(i: Actor) -> void:
	play_sound("Entrance", i)
	await Event.wait(0.3)
	await anim(&"Entrance", i)
	if i.node.animation == &"Entrance" or i.node.animation == &"Idle": anim("", i)


func _on_next_turn() -> void:
	if check_for_victory(): return
	#position_sprites()
	Turn += 1

	if follow_up_next:
		follow_up_text()
		follow_up_next = false
		TurnInd = TurnOrder.find(CurrentChar)
	else:
		if TurnOrder.size() - 1 <= TurnInd:
			TurnInd = 0
		else:
			TurnInd += 1

	CurrentChar = TurnOrder[TurnInd]

	if CurrentChar.node == null:
		_on_next_turn()
		return

	print("-------------------------------------------------")
	print_rich("[color=cornflower-blue]Turn: ", Turn, " - Index: ", TurnInd, " - Name: ", CurrentChar.FirstName)
	initial = CurrentChar.node.position

	if CurrentChar.has_state("Knocked Out"):
		if CurrentChar.IsEnemy:
			Troop.erase(CurrentChar)
			TurnOrder.erase(CurrentChar)
			if Troop.is_empty():
				victory()
				return
			else:
				end_turn()
				return

	if CurrentChar.IsEnemy: enemy_ui._on_battle_ui_target_foc(CurrentChar)
	else: enemy_ui.all_enemy_ui()
	act.handle_states()


func check_for_victory() -> bool:
	var j: int = 0

	for i in Troop:
		if i.has_state("Knocked Out"): j += 1

	if j == Troop.size() or Troop.size() == 0:
		victory()
		return true
	else: return false


func make_move() -> void:
	if check_for_victory(): return
	if CurrentChar.NextAction == Actor.BtAction.UNSET:
		if CurrentChar.Controllable:
			print_rich("[color=cornflower-blue]Control")
			GetControl.emit()
		else:
			$AI.ai()
	else:
		print_rich("[color=cornflower-blue]Forced move")
		confirm_next()


func _on_ai_chosen() -> void:
	confirm_next()


func confirm_next(action_anim := true) -> void:
	if CurrentChar.NextMove == null:
		CurrentChar.NextMove = Ability.nothing() 

	if CurrentChar.Controllable: ui.close()
	
	if CurrentChar.NextMove == CurrentChar.StandardAttack:
		CurrentChar.NextAction = Actor.BtAction.ACT

	print_rich("[color=cornflower-blue]Action: ", CurrentChar.NextAction)

	if action_anim:
		match CurrentChar.NextAction:
			Actor.BtAction.MAGIC:
				focus_cam(CurrentChar)
				zoom(5.5)
				callout(CurrentChar.NextMove)
				var timer := get_tree().create_timer(0.5)
				await anim("Ability")
				if timer.time_left != 0: await timer.timeout

			Actor.BtAction.ITEM:
				focus_cam(CurrentChar)
				zoom(5.5)
				var pos := CurrentChar.node.get_global_transform_with_canvas().origin
				Item.use_animation(CurrentChar.NextMove.Icon, CurrentChar.NextMove.name, pos)
				await Event.wait(2)

	if CurrentChar.NextTarget == null:
		CurrentChar.NextTarget = random_target(CurrentChar.NextMove)

	_on_battle_ui_ability_returned(CurrentChar.NextMove, CurrentChar.NextTarget)


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("DebugR"):
		end_battle()

	if Input.is_action_just_pressed("DebugV"):
		for i in Troop:
			death(i)

		ui.close()
		victory()

	if Input.is_action_pressed("Dash") and Action:
		Engine.time_scale = 8
		cam.position_smoothing_enabled = false
	elif Input.is_action_just_released("Dash"):
		Engine.time_scale = 1

	if AwaitVictory:
		if Input.is_action_just_released("ui_accept"):
			end_battle()

	if Input.is_action_just_pressed("DebugF"):
		print(relation_to_dmg_modifier(color_relation(CurrentChar.MainColor,
		ui.target.MainColor)))


func _on_battle_ui_ability() -> void:
	if CurrentChar.node == null: return
	if ui.PrevStage == "root":
		play_sound("Ability", CurrentChar)
		await anim("Ability")

	if CurrentChar.node.animation == "Ability": anim("AbilityLoop")


func _on_battle_ui_root() -> void:
	Engine.time_scale = 1
	enemy_ui.all_enemy_ui()
	stop_sound("Ability", CurrentChar)
	anim()


func callout(ab: Ability = CurrentAbility) -> void:
	if not ab.Callout:
		return

	var tc := create_tween()
	tc.set_ease(Tween.EASE_OUT)
	tc.set_trans(Tween.TRANS_QUINT)
	if callout_onscreen:
		tc.tween_property($Canvas/Callout, "modulate", Color.TRANSPARENT, 0.2)
		await tc.finished
		tc.kill()
		tc = create_tween()
		tc.set_ease(Tween.EASE_OUT)
		tc.set_trans(Tween.TRANS_QUINT)

	callout_onscreen = true

	if ab.ColorSameAsActor: ab.WheelColor = CurrentChar.MainColor
	$Canvas/Callout.text = ab.name
	$Canvas/Callout.add_theme_color_override("font_color", ab.WheelColor)
	tc.tween_property(
		$Canvas/Callout, "position", Vector2(37, 636), 2).from(Vector2(400, 636))

	tc.parallel().tween_property(
		$Canvas/Callout, "modulate", Color.WHITE, 2).from(Color.TRANSPARENT)

	#await tc.finished
	#print_rich("[color=cornflower-blue]call")
	tc.set_ease(Tween.EASE_IN)
	if CurrentChar.Controllable:
		tc.tween_property(
			$Canvas/Callout, "position", Vector2(-200, 636), 0.5).set_delay(1)
	else: tc.tween_property(
		$Canvas/Callout, "position", Vector2(-200, 636), 0.5).set_delay(4)

	tc.parallel().tween_property(
		$Canvas/Callout, "modulate", Color.TRANSPARENT, 0.5)

	await tc.finished
	callout_onscreen = false


func _on_battle_ui_ability_returned(ab: Ability, tar: Actor) -> void:
	if not is_instance_valid(tar): return
	print_rich("[color=cornflower-blue]Using ", ab.name, " on ", tar.FirstName)

	for i in CurrentChar.BattleLog: if i.turn == Turn:
		print_rich("[color=cornflower-blue]Double turn detected, aborting")
		return

	var log_entry := Actor.log_entry.new()
	log_entry.ability = ab; log_entry.target = tar; log_entry.turn = Turn
	CurrentChar.BattleLog.append(log_entry)
	CurrentChar.NextAction = Actor.BtAction.UNSET
	CurrentChar.NextMove = null
	CurrentChar.NextTarget = null
	CurrentAbility = ab
	CurrentTarget = tar

	if CurrentChar.has_state("Bound") and (CurrentAbility.Damage == Ability.D.WEAPON or CurrentAbility == CurrentChar.StandardAttack):
		CurrentAbility = Ability.nothing()
		battle_msg("struggle")
		await shake_actor(CurrentChar)
		end_turn()
		return

	if ab.remove_item_on_use != null:
		Item.remove_item(ab.remove_item_on_use)

	if ab == null:
		end_turn()
		return

	if ab.ColorSameAsActor:
		ab.WheelColor = CurrentChar.MainColor

	if ab.Target == 1:
		if tar and tar.has_state("Knocked Out"):
			var i := -1
			var oldtar := CurrentTarget.FirstName

			while (CurrentTarget.FirstName == oldtar or
			CurrentTarget.has_state("Knocked Out") or CurrentTarget.node == null):
				i += 1

				if i > get_ally_faction(CurrentTarget).size():
					if get_ally_faction(CurrentTarget)[0].IsEnemy:
						victory()
						return
					else:
						game_over()
						return

				CurrentTarget = get_ally_faction(CurrentTarget)[i - 1]

		if tar.IsEnemy:
			ui.emit_signal("targetFoc", tar)
	elif ab.Target == 0:

		if CurrentChar.IsEnemy:
			ui.emit_signal("targetFoc", CurrentChar)

	if CurrentChar.IsEnemy:
		ui.emit_signal("targetFoc", CurrentChar)
	elif ab.Target == 2: enemy_ui.all_enemy_ui()

	if ab.ActionSequence != &"":
		CurrentChar.add_aura(-CurrentAbility.AuraCost)
		if CurrentAbility.Callout and CurrentChar.Controllable:
			callout()

		act.play(ab.ActionSequence, CurrentTarget)
	else:
		end_turn()
		return


## Used for showing toasts. These can be set in BattleText from the editor.
## Certain strings are replaced, as seen below
func battle_msg(id: String, insert := "MISSING", insert2 := "MISSING2") -> String:
	var target := CurrentTarget if CurrentTarget else Troop[0]
	var text := BattleText[id]
	text = text.replace("[cur]", CurrentChar.FirstName)
	text = text.replace("[tar]", target.FirstName)
	text = text.replace("[insert]", insert)
	text = text.replace("[insert2]", insert2)
	text = text.replace("[cur_themself]", CurrentChar.get_pronoun("themself"))
	text = text.replace("[cur_they]", CurrentChar.get_pronoun("they"))
	text = text.replace("[cur_them]", CurrentChar.get_pronoun("them"))
	text = text.replace("[cur_their]", CurrentChar.get_pronoun("their"))
	text = text.replace("[tar_themself]", target.get_pronoun("themself"))
	text = text.replace("[tar_they]", target.get_pronoun("they"))
	text = text.replace("[tar_them]", target.get_pronoun("them"))
	text = text.replace("[tar_their]", target.get_pronoun("their"))
	Global.toast(text)
	return text


func jump_to(
	character: Actor, to_position: Vector2, time: float, height: float = 0.5
) -> void:
	var t := create_tween()
	var start_pos := character.node.position
	var jump_distance: float = start_pos.distance_to(to_position)
	var jump_height: float = jump_distance * height
	var midpoint := start_pos.lerp(to_position, 0.5) + Vector2.UP * jump_height
	var jump_time := jump_distance * (time * 0.001)
	t.tween_method(
		Query.quad_bezier.bind(start_pos, midpoint, to_position, character.node),
		0.0,
		1.0,
		jump_time
	)
	await t.finished
	anim_done.emit()


func jump_to_target(
	character: Actor, tar: Actor, offset: Vector2, time: float, height: float = 0.5
) -> void:
	await jump_to(character, tar.node.position + offset, time, height)


func return_cur(target: Actor = CurrentChar) -> void:
	await jump_to(target, initial, 1, 0.2)


func end_turn(confirm_aoe := false) -> void:
	Global.check.emit()
	if CurrentAbility.is_aoe() and not confirm_aoe:
		aoe_returns += 1
		return

	if ignore_end_turn: return
	aoe_returns = 0

	for i in TurnOrder:
		if i.Aura == 0 and not i.has_state("AuraBreak") and not i.has_state("UnbreakingAura") and not i.has_state("KnockedOut") and i.Health != 0:
			await i.add_state("AuraBreak")
			if i != CurrentChar:
				follow_up_next = true

	if sequence.check_events() and not follow_up_next:
		await Event.wait(0.5)
		await sequence.call_events()

	sequence.reset_events()
	TurnOrder.sort_custom(speed_sort)
	#for i in TurnOrder:
		#print(i.Speed+i.SpeedBoost, " - ", i.FirstName)

	while lock_turn:
		await Event.wait()

	await get_tree().create_timer(0.1).timeout
	act.end_turn_checks()
	if is_instance_valid(CurrentChar.node):
		CurrentChar.node.z_index = 0

	for i in TurnOrder:
		if i.queue_delete:
			delete_actor(i)

	next_turn.emit()


func damage(
	target: Actor, 
	is_magic := CurrentAbility.Damage != Ability.D.WEAPON, 
	elemental := false,
	x: int = Query.calc_num(), 
	effect := true,
	limiter := false, 
	ignore_stats := false,
	overwrite_color: Color = Color.WHITE
) -> int:
	take_dmg.emit()
	if CurrentAbility == null: CurrentAbility = Ability.nothing()
	
	## Elemental modifier
	var el_mod: float = 1
	## Color of the offending ability
	var color := (CurrentAbility.WheelColor if overwrite_color == Color.WHITE else overwrite_color)
	## Relation from the ability to the target
	var relation := color_relation(color, target.MainColor)
	
	if elemental:
		el_mod = relation_to_dmg_modifier(relation)
		print("Relation: %s	Modifier: %d"%[relation, el_mod])

	print_rich("[color=cornflower-blue]Attack power: ", x, " * ", el_mod)
	
	## Attacker to get offensive stats from (null if stats are ignored)
	var offender: Actor = null if ignore_stats else CurrentChar
	## Initial number of damage
	var dmg: int = target.calc_dmg(x * el_mod, is_magic, offender)
	
	## State specific modifications
	for state in target.States:
		# Mutiply with each state's modifiers
		if is_magic:
			dmg = int(dmg * state.magic_dmg_mult)
		else:
			dmg = int(dmg * state.weapon_dmg_mult)

		match state.filename:
			"Frozen":
				target.remove_state("Frozen")
				battle_msg("ice_breaks", target.FirstName)

			"Guarding":
				# With Guarding, you nothing is weak
				if relation != "res":
					relation = "n"
					el_mod = min(el_mod, 1)

			"AuraBreak":
				# With AuraBreak, everything is weak
				if relation != "op":
					relation = "wk"
					el_mod = max(el_mod, 1)

		if relation == "wk":
			dmg = int(dmg * state.weak_mult)

	# If damage is 0, don't do anything below
	if dmg == 0:
		pop_num(target, "BLOCKED")
		return 0

	# Clutch damage, health should never go to 0
	if (
		((target.ClutchDmg and target.Health > 0.2*target.MaxHP) 
		or target.CantDie) and target.Health - dmg < 0
	):
		print("Damage on ", target.FirstName, " was clutched")
		limiter = true
		queue_sequence_for_actor(target, target.DeathSequence)

	# Actual damage happens
	target.damage(dmg, limiter)
	print(CurrentChar.FirstName + " deals " + str(dmg) + " damage to " + target.FirstName)

	# Effects!
	if not is_magic and CurrentChar.has_state("AtkUp") and CurrentChar.get_state("AtkUp").turns == -2:
		CurrentChar.get_state("AtkUp").QueueRemove = true
		print_rich("[color=cornflower-blue]Weapon attack, so AtkUp will be removed")

	if CurrentAbility.RecoverAura: CurrentChar.add_aura(dmg / 2)

	if elemental:
		var base_dmg := int(dmg * target.Defence * 2 * target.DefenceMultiplier)
		var aur_dmg := relation_to_aura_dmg(relation, base_dmg)
		print(target.FirstName, " takes ", aur_dmg, " aura damage")
		target.add_aura(-aur_dmg)
		pop_num(target, dmg, color)
		
		# Show the popup text
		match relation:
			"wk": pop_num(target, "WEAK")
			"op": pop_num(target, "WEAK!")
			"res": pop_num(target, "RESIST")
	else: pop_num(target, dmg)

	if !target.IsEnemy:
		Hud.hit_partybox(Party.current.find(target), int(dmg / 2), int(dmg * 100 / target.MaxHP * 100) / 300)
	else:
		Event.node_shake(enemy_ui.get_node("EnemyFocus"), int(dmg), int(dmg * 100 / target.MaxHP * 100) / 300)

	if target.Controllable:
		Controller.rumble(remap(dmg * 2, 0, target.MaxHP, 0, 1), remap(dmg, 0, 100, 0, 1), remap(dmg * 2, 0, target.MaxHP, 0, 1))
	elif CurrentChar.Controllable:
		Controller.rumble(remap(dmg, 0, target.MaxHP, 0, 0.5), remap(dmg, 0, 100, 0, 1), remap(dmg, 0, target.MaxHP, 0, 0.5))
	else:
		Controller.rumble(remap(dmg, 0, target.MaxHP, 0, 0.3), remap(dmg, 0, 100, 0, 0.5), remap(dmg, 0, 100, 0, 0.5))

	check_party.emit()
	if target.Health == 0:
		if target.CantDie:
			target.Health = 1
		else:
			await death(target)
			if target != CurrentChar and relation == "wk": follow_up_next = true
			return dmg

	if target.Health == 0 or target.has_state("Knocked Out"): return dmg

	if target.has_state("Guarding"):
		if relation == "res": target.add_aura(dmg * 2)
		else: target.add_aura(dmg)
	elif effect:
		play_sound("Hit", target)
		hit_animation(target)
		if elemental and not target.has_state("AuraBreak"):
			if el_mod > 1:
				target.node.get_node("Particle").emitting = true

			outline(target)
			target.node.get_node("Particle").process_material.gravity = Vector3(offsetize(120), 0, 0)
			target.node.get_node("Particle").process_material.color = target.MainColor
			await outline_remove(target)
			Input.stop_joy_vibration(0)

	target.DamageRecivedThisTurn += dmg
	return dmg


func queue_sequence_for_actor(chara: Actor, sequence_name: String) -> void:
	var ab := Ability.nothing().duplicate()
	ab.name = sequence_name
	ab.ActionSequence = sequence_name
	
	chara.NextMove = ab
	chara.NextAction = Actor.BtAction.ACT


func hit_animation(tar: Actor) -> void:
	if tar.node.animation != "KnockedOut":
		anim("Hit", tar)
		await tar.node.animation_finished
		anim("Idle", tar)


func outline(target: Actor, color: Color = target.MainColor) -> void:
	if target.node.material.get_shader_parameter("outline_enabled") != null:
		target.node.material.set_shader_parameter("outline_enabled", true)
		target.node.material.set_shader_parameter("outline_color", color)


func outline_remove(target: Actor, time := 0.5) -> void:
	if target.node.material.get_shader_parameter("outline_enabled") != null:
		var t := create_tween()
		t.tween_property(target.node.material, "shader_parameter/outline_color", Color.TRANSPARENT, time)
		await t.finished
		target.node.material.set_shader_parameter("outline_enabled", false)


func screen_shake(amount: float = 15, times: float = 7, ShakeDuration: float = 0.2) -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	var dur := ShakeDuration / times
	var am := amount

	if Input.get_joy_vibration_strength(0) == Vector2.ZERO:
		Controller.rumble(amount / 20, times / 10, ShakeDuration)

	for i in range(0, times):
		am = am - (amount / times)
		#print(am)
		#print(amount, " / ", times, " = ",amount/times)
		t.tween_property(cam, "offset",
		Vector2(randf_range(-am, am), randf_range(-am, am)), dur).as_relative()
		t.tween_property(cam, "offset", Vector2.ZERO, dur)

	await t.finished


func play_effect(stri: String, tar: Variant, offset := Vector2.ZERO, flip_on_player_use := false, dont_free := false) -> void:
	if effects.sprite_frames.has_animation(stri):
		print_rich("[color=cornflower-blue]Playing effect ", stri)

		if tar is not Vector2:
			if tar is Actor and is_instance_valid(tar) and is_instance_valid(tar.node): tar = tar.node.position
			else:
				push_error("The target of the effect ", stri, " was invalid")
				return

		var ef: AnimatedSprite2D = effects.duplicate()

		if flip_on_player_use and !CurrentChar.IsEnemy: ef.flip_h = true
		ef.name = stri
		act.add_child(ef)
		ef.position = tar + offset
		ef.play(stri)
		await ef.animation_finished
		if not dont_free: ef.queue_free()


func cut_in(image: String = CurrentChar.codename) -> void:
	#Engine.time_scale = 0.1
	var img: Texture = await Loader.load_res("res://art/Pictures/Cutin_" + image + ".png")
	$Canvas/Cutin/Texture.texture = img
	$Canvas/Cutin.show()
	var t := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property($Canvas/Cutin, "size:y", 380, 0.3).from(0)
	t.tween_property($Canvas/Cutin, "position:y", 185, 0.3).from(400)
	t.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property($Canvas/Cutin/Texture, "position", Vector2(0, -145), 1.5).from(Vector2(-1000, 0))
	#t = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	#t.tween_property($Canvas/Cutin/Texture, "position", Vector2(0, -148), 1).from(Vector2(-121, 0))
	await t.finished
	#await Event.wait(1.5)
	t = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD)
	t.tween_property($Canvas/Cutin, "size:y", 0, 0.2)
	t.tween_property($Canvas/Cutin, "position:y", 400, 0.2)
	t.tween_property($Canvas/Cutin/Texture, "position", Vector2(1000, -300), 0.2)
	await t.finished
	$Canvas/Cutin.hide()


func offsetize(num: float, target := CurrentChar) -> float:
	if target == null: return num
	#if CurrentAbility and CurrentAbility.Target == 0:
		#return 0

	if target.IsEnemy:
		return -num
	else:
		return num


func is_valid_target(target: Actor, ability: Ability = CurrentChar.NextMove) -> bool:
	if ability == null: return true
	if ability.Target == Ability.T.ONE_ENEMY or ability.Target == Ability.T.AOE_ENEMIES:
		if target in get_ally_faction(): return false

	if ability.Target == Ability.T.ONE_ALLY or ability.Target == Ability.T.AOE_ALLIES:
		if target in get_oposing_faction(): return false

	if target.has_state("KnockedOut"):
		if !ability.CanTargetDead: return false

	return true


func recover(chara: Actor) -> void:
	battle_msg("recovers", chara.FirstName)
	anim("Idle", chara)
	chara.Health = max(10, chara.Health)
	chara.Aura = chara.MaxAura


func pop_num(target: Actor, text: Variant, color: Color = Color.WHITE) -> void:
	if is_instance_valid(target) and target.node != null:
		var number: Label = target.node.get_node("Nums").duplicate()
		target.node.add_child(number)
		number.modulate = Color.TRANSPARENT
		number.show()
		number.add_theme_color_override("font_color", color)
		var tn := create_tween()
		tn.set_ease(Tween.EASE_IN)
		tn.set_trans(Tween.TRANS_QUART)
		number.text = str(text)
		var off: int = 1

		if text is String: off = 0
		tn.tween_property(number, "position", Vector2(offsetize(20 * off) *
			randf_range(0.8, 1.2), -10 * randf_range(0.8, 1.2)),
			0.3).as_relative().from(Vector2(-217, -36))

		tn.parallel().tween_property(number, "modulate",
			Color.WHITE, 0.3).from(Color.TRANSPARENT)

		tn.set_ease(Tween.EASE_OUT)
		tn.tween_property(number, "modulate",
			Color.TRANSPARENT, 2).from(Color.WHITE)

		tn.parallel().tween_property(number, "position",
			Vector2(offsetize(14 * off) *
			randf_range(0.8, 1.2), -6 * randf_range(0.8, 1.2)), 2).as_relative()

		await tn.finished
		if is_instance_valid(number):
			number.queue_free()


func play_sound(SoundName: String, actor: Actor = null, volume: float = 1) -> void:
	$AudioListener2D.make_current()
	var player: AudioStreamPlayer2D
	if actor and actor.node.get_node("SFX").has_node(SoundName):
		player = actor.node.get_node("SFX").get_node(SoundName)
	else:
		player = $Audio/Stream0.duplicate()
		$Audio.add_child(player)
		if not ResourceLoader.exists("res://sound/SFX/Battle/" + SoundName + ".ogg"): return
		player.stream = await Loader.load_res("res://sound/SFX/Battle/" + SoundName + ".ogg")

		if actor: player.global_position = actor.node.global_position

	player.play()
	player.volume_db = volume
	await player.finished
	if player.get_parent() == $Audio: player.queue_free()


func stop_sound(SoundName: String, actor: Actor) -> void:
	if actor.node.get_node("SFX").has_node(SoundName):
		actor.node.get_node("SFX").get_node(SoundName).stop()


## Runs when an actor is defeated, usually when HP reaches 0
func death(target: Actor) -> void:
	# Skip if already dead
	if not is_instance_valid(target): return
	if target == null or target.has_state("KnockedOut"): return

	# Turn must not end until everything here has finished
	lock_turn = true

	clear_states(target)

	# TODO: Determine if this is balanced enough or not
	if CurrentChar != target:
		CurrentChar.add_aura(target.Aura)

	target.set_aura(0)
	target.set_health(0)
	# Rewards
	if target.IsEnemy:
		totalSP += target.RecivedSP

		if target.DroppedItem:
			ObtainedItems.append(target.DroppedItem)

	anim("KnockOut", target)

	if not target.IsEnemy and filter_dead(Party.current).is_empty():
		game_over(target)

	# Effects
	var particle: GPUParticles2D = target.node.get_node("Particle")
	particle.emitting = true
	outline(target)
	particle.process_material.gravity = Vector3(offsetize(120), 0, 0)
	particle.process_material.color = target.MainColor
	var td := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	td.tween_property(target.node.get_node("Shadow"), "modulate", Color.TRANSPARENT, 0.5)
	if target.Disappear:
		td.parallel().tween_property(target.node.get_node("Glow"), "energy", 0, 0.5)

	outline_remove(target)

	print(target.FirstName, " was defeated")
	target.add_state("KnockedOut")

	await Event.wait(1)
	if not target.DeathSequence.is_empty() and not target.CantDie:
		await act.call(target.DeathSequence, target)

	lock_turn = false

	# Wait for animations to finish, then delete character if applicable
	if is_instance_valid(target.node):
		if target.Disappear and not target.CantDie:
			while target.node.is_playing() and target.node.animation == "KnockOut":
				await Event.wait()

			if is_instance_valid(target) and is_instance_valid(target.node):
				target.queue_delete = true
				target.node.hide()


## Pass a target to show a dramatic last hit animation
func game_over(target: Actor = null) -> void:
	lock_turn = true
	Audio.fade_out_music(2)
	if target != null:
		await Event.wait(0.2)
		get_tree().paused = true
		CurrentChar.node.pause()
		target.node.pause()
		await screen_shake(20, 10, 0.2)
		await Event.wait(0.7, false)
		CurrentChar.node.play()
		target.node.play()
		get_tree().paused = false
		await Event.wait(1, false)

	Loader.white_fadeout(0, 1, 2)
	await Event.wait(3, false)

	print_rich("[color=cornflower-blue]Game over")

	if sequence.DefeatSequence == "":
		Global.game_over()
	else: act.call(sequence.DefeatSequence)


func delete_actor(target: Actor) -> void:
	if is_instance_valid(target) and is_instance_valid(target.node):
		target.node.queue_free()
		target.node = null

		if target.IsEnemy:
			Troop.erase(target)
			TurnOrder.erase(target)


func slowmo(timescale := 0.5, time := 1.0) -> void:
	Engine.time_scale = 0.5
	await Event.wait(time * timescale)
	Engine.time_scale = 1


func get_ally_faction(actor: Actor = CurrentChar, filter_out_dead := true) -> Array[Actor]:
	var rtn: Array[Actor]
	if actor.IsEnemy: rtn = Troop
	else: rtn = Party.current

	if filter_out_dead: rtn = filter_dead(rtn)
	return rtn


func get_oposing_faction(actor: Actor = CurrentChar, filter_out_dead := true) -> Array[Actor]:
	var rtn: Array[Actor]
	if actor.IsEnemy: rtn = Party.current
	else: rtn = Troop

	if filter_out_dead: rtn = filter_dead(rtn)
	return rtn


func get_target_faction(ab := CurrentAbility) -> Array[Actor]:
	match ab.Target:
		Ability.T.AOE_ALLIES: return get_ally_faction(CurrentChar, !ab.CanTargetDead)
		Ability.T.AOE_ENEMIES: return get_oposing_faction()
		_: return [CurrentTarget]


func get_any_faction(filter_out_dead := true) -> Array[Actor]:
	var rtn: Array[Actor]
	rtn.append_array(Party.current)
	rtn.append_array(Troop)
	if filter_out_dead: rtn = filter_dead(rtn)
	return rtn


func hp_sort(a: Actor, b: Actor) -> bool:
	return a.Health < b.Health

var t_glow: Tween


func anim(animation: String = "", chara: Actor = CurrentChar) -> void:
	if chara.node == null: return
	if chara.FlipH:
		chara.node.flip_h = true

	if not is_instance_valid(chara):
		battle_msg("seq_error")
		return

	if animation == "" or chara.has_state("KnockedOut"):
		if chara.DontIdle: return
		else:
			animation = "Idle"

			for i in chara.States:
				if i.pose != "None" and i.pose in chara.node.sprite_frames.get_animation_names():
					anim(i.pose, chara)

	if animation not in chara.node.sprite_frames.get_animation_names():
		return

	if animation in chara.GlowAnims and chara.GlowSpecial != 0:
		t_glow = create_tween()
		chara.node.get_node("Glow").color = chara.MainColor
		t_glow.tween_property(chara.node.get_node("Glow"), "energy", chara.GlowSpecial, 0.3)
	elif chara.node.animation in chara.GlowAnims and chara.GlowSpecial != 0:

		if is_instance_valid(t_glow):
			t_glow.kill()

		t_glow = create_tween()
		chara.node.get_node("Glow").color = chara.MainColor
		t_glow.tween_property(chara.node.get_node("Glow"), "energy", chara.GlowDef, 0.3)

	chara.node.play(animation)
	pixel_perfectize(chara)
	print_rich("[color=cornflower-blue]Animation: ", animation)

	while chara.node and chara.node.is_playing() and chara.node.animation == animation:
		await Event.wait()


func glow(amount: float = 1, time: float = 1, chara: Actor = CurrentChar) -> void:
	if is_instance_valid(t_glow):
		t_glow.kill()

	t_glow = create_tween()
	t_glow.tween_property(chara.node.get_node("Glow"), "energy", amount, time)


func pixel_perfectize(chara: Actor, xy: int = 0) -> void:
	if not is_instance_valid(chara.node.sprite_frames): return
	var frame := chara.node.sprite_frames.get_frame_texture(chara.node.animation, chara.node.frame)

	if frame == null: return
	if int(frame.get_size()[xy]) % 2 == 0:
		chara.node.offset[xy] = chara.Offset[xy]
	else: chara.node.offset[xy] = chara.Offset[xy] + 0.5

	if xy == 0: pixel_perfectize(chara, 1)


func focus_cam(chara: Actor, time: float = 0.5, offset: Variant = 30) -> void:
	if chara.node == null: return
	if offset is int:
		await move_cam(Vector2(chara.node.position.x + offsetize(offset, chara), chara.node.position.y / 2), time)
	elif offset is Vector2:
		move_cam(Vector2(chara.node.position.x, chara.node.position.y / 2) + Vector2(offsetize(offset.x, chara), offset.y), time)

var t_move_cam: Tween


func move_cam(pos: Vector2, time: float = -1) -> void:
	if Input.is_action_pressed("Dash") or time == 0:
		cam.position_smoothing_enabled = false
	else:
		cam.position_smoothing_enabled = true

	if time > 0:
		if is_instance_valid(t_move_cam):
			t_move_cam.kill()

		t_move_cam = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t_move_cam.tween_property(cam, "position", pos, time)
	else:
		cam.position = pos

	await Event.wait(time)

var t_zoom: Tween


func zoom(am: float = 5, time: float = 0.5, easing := Tween.EASE_IN_OUT) -> void:
	if is_instance_valid(t_zoom):
		t_zoom.kill()

	t_zoom = create_tween()
	t_zoom.set_ease(easing)
	t_zoom.set_trans(Tween.TRANS_CUBIC)
	t_zoom.tween_property(cam, "zoom", Vector2(am, am), time)
	await t_zoom.finished


func move(
	chara: Actor,
	pos: Vector2,
	time: float,
	mode: Tween.EaseType = Tween.EASE_IN_OUT,
	offset: Vector2 = Vector2.ZERO
) -> void:
	if is_instance_valid(chara) and chara.node != null:
		var tm := create_tween()
		tm.set_ease(mode)
		tm.set_trans(Tween.TRANS_QUART)
		tm.tween_property(chara.node, "position", pos + offset, time)
		await tm.finished

	anim_done.emit()


#int(max(Query.calc_num(), target.MaxHP*((Query.calc_num()*CurrentChar.Magic)*0.02)))
func heal(
	target: Actor,
	amount: int = Query.calc_num() * int(CurrentChar.Magic * CurrentChar.MagicMultiplier)
) -> void:
	if CurrentAbility.DmgVarience:
		amount = round(amount * randf_range(1, 1.5))

	amount = min(amount, target.MaxHP - target.Health)
	target.add_health(amount)
	ui.targetFoc.emit(target)
	check_party.emit()
	Hud._check_party()
	pop_aura(target)
	pop_num(target, "+" + str(amount))


func remove_queued_states(chara: Actor) -> void:
	if not is_instance_valid(chara): return
	for i in range(chara.States.size() - 1, -1, -1):
		var state := chara.States[i]

		if state.QueueRemove:
			chara.remove_state(state)

	if chara.States.is_empty(): chara.node.get_node("State").play("None")


func pop_aura(target: Actor, time: float = 0.5) -> void:
	outline(target, Color.WHITE)
	await get_tree().create_timer(time).timeout
	await outline_remove(target)


func escape() -> void:
	print_rich("[color=cornflower-blue]Escaped")
	battle_result = Result.ESCAPE
	end_battle()


func end_battle() -> void:
	AwaitVictory = false
	reset_all()
	canvas.get_node("Continue").hide()
	await Hud.preform_levelups()
	if Global.room == null: Loader.travel_to("Debug"); queue_free(); return
	Audio.fade_out_music()
	
	Hud.shrink()
	if sequence.Detransition or battle_result != Result.VICTORY:
		hide_victory_stuff()
		Global.bt.zoom(4)
		Loader.battle_bars(4)
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(Global.bt):
			Global.bt.queue_free()
	else:
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUART)
		t.set_parallel()
		#Engine.time_scale = 0.1
		Global.room.setup_zoom(true)
		for i in Global.bt.TurnOrder:
			t.tween_property(i.node.get_node("Glow"), "energy", 0, 0.3)

		Global.bt.get_node("Background").material = null
		t.tween_property(Global.bt.get_node("Background"), "modulate", Color.TRANSPARENT, 0.5)
		hide_victory_stuff()

	in_battle = false
	Global.camera.position_smoothing_enabled = true

	if not is_instance_valid(Global.player):
		return

	for i in Global.room.followers:
		if i and Party.has_member_index(i.member):
			i.show()

	Global.player.set_anim("IdleRight")
	Global.player.dashing = false
	
	post_battle()
	
	Global.camera.make_current()
	act.free()
	queue_free()
	battle_end.emit()


static func post_battle() -> void:
	if battle_result == Result.ESCAPE:
		Global.player.position = Query.globalize(sequence.EscPosition)

	if is_instance_valid(attacker):
		if battle_result != Result.VICTORY:
			attacker.show()

		if sequence.DeleteAttacker and battle_result == 1:
			if Global.player.is_on_wall():
				Global.player.position = attacker.position

			attacker.defeat()

	Global.controllable = false
	Loader.battle_bars(0)
	if is_instance_valid(Global.player):
		Global.player.show()
		Global.player.get_node("DirectionMarker/Finder/Shape").set_deferred("disabled", false)
		if Event.f(&"FlameActive"):
			Global.player.activate_flame()

	if sequence.ReturnControl:
		Hud.ui_visible = true
		Event.give_control(true)

	Hud.shrink()


func hide_victory_stuff() -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.set_parallel()
	for i in Global.bt.get_node("Canvas").get_children():
		if i.name != "DottedBack":
			t.tween_property(i, "position:x", i.position.x + 500, 0.3)
			t.tween_property(i, "modulate", Color.TRANSPARENT, 0.3)

	t.tween_property(Global.bt.get_node("Canvas/DottedBack"), "modulate", Color(0.188, 0.188, 0.188, 0), 0.5)


func reset_all() -> void:
	for i in TurnOrder:
		for j in i.States: if j.RemovedOnBattleEnd: i.States.erase(j)
		i.AttackMultiplier = 1
		i.DefenceMultiplier = 1
		i.MagicMultiplier = 1
		i.SpeedBoost = 0

	for i in Party.members:
		if i.AuraDefault != Color.WHITE:
			i.MainColor = i.AuraDefault
			i.AuraDefault = Color.WHITE

		i.Health = max(i.Health, 10)
		i.Aura = max(i.Aura, 5)


func victory_anim(chara: Actor) -> void:
	act.process_mode = Node.PROCESS_MODE_ALWAYS
	clear_states(chara)
	await anim("Victory", chara)
	anim("VictoryLoop", chara)


func victory_count_sp() -> void:
	await Event.wait(0.7, false)
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.set_parallel()
	$Canvas/SPGain.show()
	t.tween_property($Canvas/SPGain, "position:x", 918, 0.5).from(1000)
	t.tween_property($Canvas/SPGain, "modulate",
		Color.WHITE, 0.5).from(Color.TRANSPARENT)

	t.tween_property($Canvas/SPGain, "size:x", 260, 0.5).from(1)
	t.tween_property($Canvas/SPGain/VBoxContainer/Text,
		"custom_minimum_size:x", 140, 0.5).from(1)

	for i in Party.current:
		i.add_SP(totalSP)

	Hud._check_party()
	await Event.wait(0.5, false)
	var sp := totalSP
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.tween_property(self, "count_sp", sp, 2).from(0)
	while $Canvas/SPGain/VBoxContainer/Number.text != str(sp):
		$Canvas/SPGain/VBoxContainer/Number.text = str(count_sp)
		await Event.wait()

	var dub: PanelContainer = $Canvas/SPGain.duplicate()
	$Canvas.add_child(dub)
	t = create_tween()
	t.set_parallel()
	t.tween_property(dub, "scale", Vector2(1.5, 1.5), 0.3)
	t.tween_property(dub, "modulate", Color.TRANSPARENT, 0.3)
	await Event.wait(0.3, false)
	dub.queue_free()


func victory(ignore_seq := false) -> void:
	if AwaitVictory: return
	print_rich("[color=cornflower-blue]Victory!")
	Action = true

	if sequence.VictorySequence != "" and not ignore_seq:
		act.call(sequence.VictorySequence)
		return

	if sequence.VictoryBanter != "":
		Passive.open("banter_victory", sequence.VictoryBanter)

	$Canvas.layer = 1
	battle_result = Result.VICTORY
	
	if sequence.Music.victory_track != null:
		Audio.change_music(sequence.Music.victory_track)
	elif sequence.Music.victory > 0:
		Audio.change_music_from_to(sequence.Music.track, sequence.Music.victory)
	else:
		Audio.fade_out_music(3)

	for i in Party.current:
		victory_anim(i)

	check_party.emit()
	enemy_ui.colapse_root()
	reset_all()
	var t := create_tween()
	$Canvas/VictoryText.text = sequence.VictoryText
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.set_parallel()
	enemy_ui.get_node("EnemyFocus").hide()
	$Canvas/TurnOrder.hide()
	$Canvas/VictoryText.add_theme_color_override("font_color", Color.WHITE)
	$Canvas/VictoryText.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	$Canvas/VictoryText.scale = Vector2(1.5, 1.5)
	Hud.expand(2)
	Loader.battle_bars(0)
	$Canvas/DottedBack.show()
	t.tween_property($Canvas/DottedBack, "modulate",
	Color(0.188, 0.188, 0.188, 0.8), 1).from(Color(0.188, 0.188, 0.188, 0))
	t.tween_property($Canvas/VictoryText, "position",
	Vector2(260, 50), 2).from(Vector2(1000, 50))
	t.tween_property($Canvas/VictoryText, "modulate",
	Color.WHITE, 2).from(Color.TRANSPARENT)
	t.tween_property(cam, "position", Vector2(-20, 0), 1)
	t.tween_property(cam, "zoom", Vector2(5, 5), 1)
	ObtainedItems.append_array(sequence.AdditionalItems)
	if totalSP != 0: await victory_count_sp()
	if not ObtainedItems.is_empty(): victory_show_items()
	$Canvas/TurnOrder.hide()
	$Canvas/Continue.show()
	$Canvas/Continue.icon = Controller.get_scheme().ConfirmIcon

	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.tween_property($Canvas/Continue, "position:x", 1060, 0.5).from(1500).set_delay(1)
	enemy_ui.colapse_root()
	AwaitVictory = true

	if is_instance_valid(Global.player):
		if sequence.UseBackground:
			pass
		else:
			Global.player.global_position = act.get_node("Actor0").global_position

			for i in range(1, 4):
				if Party.has_member_index(i):
					Global.room.followers[i - 1].global_position = act.get_node("Actor" + str(i)).global_position

			Global.camera.position_smoothing_enabled = false
			Global.camera.global_position = cam.global_position
			Global.camera.enabled = true
			cam.enabled = false
			Global.camera.zoom = cam.zoom


func victory_show_items() -> void:
	for i in $Canvas/VictoryItems.get_children():
		i.modulate = Color.TRANSPARENT

	await Event.wait()
	$Canvas/VictoryItems/ItemTemp.hide()
	for i in ObtainedItems:
		if i:
			var dub: PanelContainer = $Canvas/VictoryItems/ItemTemp.duplicate()
			dub.get_node("Hbox/ItemName").text = i.Name
			dub.get_node("Hbox/Icon").texture = i.Icon
			Item.find_filename(i)
			Item.add_item(i, &"", false)
			dub.show()
			$Canvas/VictoryItems.add_child(dub)

	$Canvas/VictoryItems.show()
	for i in $Canvas/VictoryItems.get_children():
		var count := 1

		if !(i == $Canvas/VictoryItems/ItemTemp or i is Label or not i.visible):
			for j in $Canvas/VictoryItems.get_children():
				if !(j == $Canvas/VictoryItems/ItemTemp or j is Label or j == i):
					if i.get_node("Hbox/ItemName").text == j.get_node("Hbox/ItemName").text:
						count += 1
						i.get_node("Hbox/Count").text = "x" + str(count)
						j.hide()

		if count > 1: i.get_node("Hbox/Count").show()

	for i in $Canvas/VictoryItems.get_children():
		if !(i == $Canvas/VictoryItems/ItemTemp or i == null):
			var t := create_tween()
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_QUINT)
			t.set_parallel()
			t.tween_property(i, "modulate", Color.WHITE, 0.5).from(Color.TRANSPARENT)
			t.tween_property(i, "position:x", i.position.x, 0.5).from(i.position.x + 500)
			await Event.wait(0.5, false)


func miss(target: Actor = CurrentTarget) -> void:
	lock_turn = true
	play_effect("Miss", target)
	var prev := target.node.position
	move(target, Vector2(target.node.position.x + offsetize(30), target.node.position.y), 0.3, Tween.EASE_OUT)
	pop_num(target, "Miss")
	if target.Controllable or CurrentChar.Controllable:
		Controller.rumble(0.3, 0, 0.3, 0.1)

	await Event.wait(0.5)
	await move(target, prev, 0.3)
	lock_turn = false


func _on_battle_ui_command() -> void:
	anim("Command")


func add_to_troop(en: Actor) -> void:
	en = en.duplicate()
	lock_turn = true
	Troop.append(en)
	var dub: AnimatedSprite2D = act.get_node("Actor0").duplicate()
	dub.name = "Enemy" + str(Troop.size() - 1)
	act.add_child(dub)
	TurnOrder.push_front(en)
	en.node = dub
	dub.sprite_frames = await en.get_BT()
	dub.material = dub.material.duplicate()
	dub.offset = en.Offset
	anim(&"Idle", en)
	en.Health = en.MaxHP
	en.Aura = en.MaxAura
	dub.get_node("SFX").queue_free()
	await Event.wait()
	dub.add_child(en.SoundSet.instantiate())
	outline_remove(en)
	TurnOrder.sort_custom(speed_sort)
	TurnInd = TurnOrder.find(CurrentChar)
	position_sprites()
	sprite_init(en)
	focus_cam(en, 0.3)
	await Event.wait(1)
	fix_enemy_node_issues()
	position_sprites()
	turn_ui_init()
	lock_turn = false


## Returns the relation between the colors when an attacker is attacking a defender
## wk: Weak
## op: Oposite, more weak
## res: Resist
## n: Neutral
func color_relation(offender: Color, defender: Color) -> String:
	var affinity := Query.get_affinity(offender)
	var def := Query.get_affinity(defender)

	if def.hue in affinity.oposing_range: return "op"
	elif def.hue in affinity.weak_range: return "wk"
	elif def.hue in affinity.resist_range: return "res"
	elif def.hue in affinity.near_range: return "res"
	else: return "n"


func relation_to_dmg_modifier(relation: String) -> float:
	var base: float
	var value_mod: float = remap(CurrentChar.MainColor.v, 0, 1, 2, 1)

	if relation == "op": base = 1.5 * value_mod
	elif relation == "wk": base = 1.25 * value_mod
	elif relation == "res": base = 0.75
	else: return 1
	return round(base * 10) / 10


func relation_to_aura_dmg(relation: String, dmg: int) -> int:
	print_rich("[color=cornflower-blue]Color value: ", CurrentChar.MainColor.v)

	if relation == "op": return int(dmg * CurrentChar.MainColor.v)
	elif relation == "wk": return int(dmg * (CurrentChar.MainColor.v / 2))
	else: return 0


func _on_battle_ui_item() -> void:
	await anim("Bag")
	if CurrentChar.node.animation == "Bag": anim("BagLoop")


func shake_actor(chara := CurrentTarget, amount := 2, repeat := 5, time := 0.03) -> void:
	if not is_instance_valid(chara.node): return
	for i in repeat:
		var t := create_tween()
		t.tween_property(chara.node, "position:x", amount, time).as_relative()
		t.tween_property(chara.node, "position:x", -amount * 2, time * 2).as_relative()
		t.tween_property(chara.node, "position:x", amount, time).as_relative()
		await t.finished


func stat_change(
	stat: StringName,
	amount: float,
	chara := CurrentChar,
	turns: int = 3
) -> void:
	var updown: String
	if amount > 0: updown = "Up"
	else: updown = "Down"

	match stat:
		&"Atk": chara.AttackMultiplier += amount
		&"Mag": chara.MagicMultiplier += amount
		&"Def": chara.DefenceMultiplier += amount

	var state := await chara.add_state(stat + updown, turns, CurrentChar)
	await Event.wait(1)
	state.parameter = amount
	pop_num(chara, stat_name(stat) +" x" + str(amount + 1), state.color)

	if updown == "Up":
		Audio.ui_sound("powerup")
	else: Audio.ui_sound("powerdown")

	print(chara.FirstName, "'  ", stat, " was multiplied by ", str(amount + 1))


func stat_name(stat: StringName) -> String:
	match stat:
		&"Atk": return "Attack"
		&"Def": return "Defence"
		&"Mag": return "Magic"
		_: return "Stat"


func on_state_add(state: State, chara: Actor, effect := true) -> void:
	if chara.Health != 0:
		add_state_effect(state, chara)
		match state.name:
			"Guarding", "AuraOverwrite":
				outline(chara)

			"MagicShield":
				outline(chara, Color.WHITE)

			"Aggro":
				chara.NextTarget = state.inflicter

		await Event.wait()
		if not state.is_stat_change and effect: pop_num(chara, state.name, state.color)


func add_state_effect(state: State, chara: Actor) -> void:
	if (
		chara.node.get_node_or_null(state.name) == null and
		chara.node.get_node("State").sprite_frames.has_animation(state.name)
	):
		var dub: AnimatedSprite2D = chara.node.get_node("State").duplicate()
		dub.name = state.name
		chara.node.add_child(dub)
		dub.show()
		dub.play(state.name)
		if state.name == "Bound":
			dub.z_index = 0


func remove_state_effect(statename: String, chara: Actor) -> void:
	if chara.node == null: return
	var state := await Query.get_state(statename)

	if chara.node.get_node_or_null(statename):
		chara.node.get_node(statename).queue_free()

	match statename:
		"Guarding", "MagicShield":
			outline_remove(chara)

		"AtkUp": chara.AttackMultiplier -= state.parameter
		"DefUp": chara.DefenceMultiplier -= state.parameter
		"MagUp": chara.MagicMultiplier -= state.parameter
		"AuraOverwrite":
			chara.MainColor = chara.AuraDefault
			outline_remove(chara)

		"KnockedOut":
			recover(chara)


func get_actor(codename: StringName, unsafe := false) -> Actor:
	if codename.is_empty(): return null
	for i in TurnOrder:
		if i.codename == codename: return i

	for i in Troop:
		if i.codename == codename: return i

	push_warning(codename + " actor not found")
	return null if unsafe else Party.Leader.duplicate()


func has_actor(codename: StringName) -> bool:
	return not get_actor(codename, true) == null


func random_target(ab: Ability) -> Actor:
	if ab.Target != Ability.T.SELF: print_rich("[color=cornflower-blue]Target decided randomly")
	match ab.Target:
		Ability.T.SELF, Ability.T.AOE_ENEMIES, Ability.T.AOE_ALLIES:
			return CurrentChar

		Ability.T.ONE_ENEMY:
			return get_oposing_faction(CurrentChar).pick_random()

		Ability.T.ONE_ALLY:
			print_rich("[color=cornflower-blue]a")
			return get_ally_faction(CurrentChar).pick_random()

	return null


func fix_enemy_node_issues() -> void:
	var i := 0

	for j in Troop:
		if j == null: continue
		if act.get_node_or_null("Enemy" + str(i)):
			j.node = act.get_node_or_null("Enemy" + str(i))

		i += 1


func filter_actors_by_state(input: Array[Actor], state: String) -> Array[Actor]:
	var rtn: Array[Actor] = []

	for i in input:
		if i.has_state(state):
			rtn.append(i)

	return rtn


func filter_dead(arr: Array[Actor]) -> Array[Actor]:
	var warr := arr.duplicate()

	for i in arr:
		if i.has_state("KnockedOut") or i.Health == 0: warr.erase(i)

	return warr


func clear_states(target: Actor) -> void:
	for i in target.States:
		target.remove_state(i)


func aura_overwrite(tar: Actor, color: Color, turns: int = 1) -> void:
	tar.AuraDefault = tar.MainColor
	tar.MainColor = color
	Global.check.emit()
	var state := await tar.add_state("AuraOverwrite", turns)

	if state != null: state.color = color
	if tar.node.material.get_shader_parameter("new_color") != null:
		tar.node.material.set_shader_parameter("new_color", color)


func confusion_msg() -> void:
	var tar: Actor = CurrentChar.NextTarget

	if CurrentChar == tar:
		battle_msg("confusion_hit_self")
	elif tar in get_ally_faction(CurrentChar) and CurrentChar.NextMove.Target == Ability.T.ONE_ENEMY:
		battle_msg("confusion_hit_ally")
	elif CurrentChar.Controllable:
		battle_msg("confusion_miss")


func follow_up_text() -> void:
	$Canvas/FollowUp.show()
	$Canvas/FollowUp/Text.position = Vector2(-1000, 600)
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)

	if CurrentChar.IsEnemy:
		$Canvas/FollowUp.rotation_degrees = 15
		t.tween_property($Canvas/FollowUp/Text, "position:x", 100, 0.5)
		t.set_ease(Tween.EASE_IN)
		t.tween_property($Canvas/FollowUp/Text, "position:x", 1400, 0.5)
	else:
		$Canvas/FollowUp.rotation_degrees = -15
		t.tween_property($Canvas/FollowUp/Text, "position:x", 450, 0.5)
		t.set_ease(Tween.EASE_IN)
		t.tween_property($Canvas/FollowUp/Text, "position:x", 1400, 0.5)
