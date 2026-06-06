extends Control

@onready var Bt: Battle = $".."
@onready var canvas: CanvasLayer = $"../Canvas"
@onready var t: Tween
@onready var trw: Tween
@onready var animation: AnimationPlayer = $"AnimationPlayer"

var TurnOrder: Array[Actor]
var CurrentChar: Actor
var Party: PartyData
var Troop: Array[Actor]
var active: bool
var stage: StringName
var CurrentTarget: Actor
var LastTarget: Actor
var tweendone := true
var MenuIndex := 0
var Abilities: Array[Ability]
var PrevStage := &"root"
var TargetFaction: Array[Actor]
var foc: Control
var analyzing := false
var disable_attack := false
var disable_ability := false
var disable_item := false
var disable_command := false

signal root
signal ability
signal attack
signal command
signal item
signal ability_returned(ab: Ability, tar: Actor)
signal targeted
signal targetFoc(ind: Actor)
signal analyze
signal rooted


func _ready() -> void:
	get_viewport().connect("gui_focus_changed", _on_focus_changed)
	hide()
	$AbilityUI.hide()
	$DescPaper.hide()
	$CommandMenu.hide()
	canvas.get_node("TurnOrder").hide()
	canvas.get_node("TurnOrderPop").hide()
	canvas.get_node("DottedBack").hide()


func _physics_process(delta: float) -> void:
	if is_instance_valid(CurrentChar) and CurrentChar.has_state("Confused"):
		$BaseRing.pivot_offset = Vector2(200 + randf_range(-1, 1), 200 + randf_range(-1, 1))


func _on_battle_get_control() -> void:
	if Bt.Troop.is_empty():
		close()
		Bt.victory()
		return
	if Bt.CurrentChar.Health == 0:
		Bt.death(Bt.CurrentChar)
		Bt.next_turn.emit()
		return

	Global.ui_sound("GetControl")
	active = true
	Loader.battle_bars(1)
	PartyUI.battle_state()
	Bt.Action = false
	stage = &"root"
	PrevStage = &"root"
	set_controller_icons()

	$Ability.add_theme_constant_override("icon_max_width", 0)
	$Attack.show()
	$Item.show()
	$Command.show()
	$Ability.show()
	$Inventory.hide()
	canvas.get_node("AttackTitle").hide()
	Troop = Bt.Troop
	TurnOrder = Bt.TurnOrder
	CurrentChar = Bt.CurrentChar
	Party = Bt.Party
	Abilities = CurrentChar.get_abilities()
	move_to(CurrentChar.node.position, 0)
	$Item.mouse_filter = MouseFilter.MOUSE_FILTER_STOP

	$Attack.disabled = false
	$Ability.disabled = false
	$Command.disabled = false
	$Item.disabled = false

	$Item.disabled = Item.ConInv.is_empty() and Item.BtiInv.is_empty()
	if CurrentChar.has_state("Bound"):
		$Attack.disabled = true
	if disable_attack or CurrentChar.CantAttack: $Attack.disabled = true
	if disable_ability: $Ability.disabled = true
	if disable_command: $Command.disabled = true
	if disable_item or not Event.check_flag("HasBag"): $Item.disabled = true

	$BaseRing/Ring2.texture.gradient.set_color(0, CurrentChar.MainColor)
	if CurrentChar.BoxProfile != null:
		var mem := CurrentChar
		$BaseRing/Ring1.texture.gradient.set_color(0, CurrentChar.BoxProfile.Bord3)
		var bord1: StyleBoxFlat = $Inventory/Border1.get_theme_stylebox("panel")
		bord1.border_color = mem.BoxProfile.Bord1
		$Inventory/Border1.add_theme_stylebox_override("panel", bord1.duplicate())
		var bord2: StyleBoxFlat = $Inventory/Border1/Border2.get_theme_stylebox("panel")
		bord2.border_color = mem.BoxProfile.Bord2
		$Inventory/Border1/Border2.add_theme_stylebox_override("panel", bord2.duplicate())
		var bord3: StyleBoxFlat = $Inventory/Border1/Border2/Border3.get_theme_stylebox("panel")
		bord3.border_color = mem.BoxProfile.Bord3
		$Inventory/Border1/Border2/Border3.add_theme_stylebox_override("panel", bord3.duplicate())

		bord1 = $AbilityUI/Border2/Border1.get_theme_stylebox("panel")
		bord1.border_color = mem.BoxProfile.Bord1
		$AbilityUI/Border2/Border1.add_theme_stylebox_override("panel", bord1.duplicate())
		bord2 = $AbilityUI/Border2.get_theme_stylebox("panel")
		bord2.border_color = mem.BoxProfile.Bord2
		$AbilityUI/Border2.add_theme_stylebox_override("panel", bord2.duplicate())
		bord3 = $AbilityUI.get_theme_stylebox("panel")
		bord3.border_color = mem.BoxProfile.Bord3
		$AbilityUI.add_theme_stylebox_override("panel", bord3.duplicate())

	fetch_abilities()
	fetch_inventory()

	Bt.move_cam(Vector2(0, 0), 0.5)
	Bt.zoom(4, 0.5)
	animation.play("get_control")
	stage = "root"


func move_to(pos: Vector2 = Vector2.ZERO, time := 0.3) -> void:
	if time > 0:
		var tm := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tm.tween_property(self, "position", pos, time)
	else:
		position = pos


func _input(event: InputEvent) -> void:
	if Global.LastInput == Global.ProcessFrame: return
	set_controller_icons()
	if active:
		match stage:
			&"root", &"pre_root":
				if event.is_action_pressed("BtAttack"):
					while Input.is_action_pressed("ui_accept"): await Event.wait()
					if $Attack.disabled:
						Global.buzzer_sound()
					else:
						attack.emit()
				if Input.is_action_just_pressed("BtCommand") and not $Command.disabled:
					command.emit()
				if Input.is_action_just_pressed("BtItem") and not $Item.disabled:
					item.emit()
				if Input.is_action_just_pressed("BtAbility") and not $Ability.disabled:
					while Input.is_action_pressed("ui_accept"): await Event.wait()
					ability.emit()
				if Input.is_action_just_pressed("Manual"):
					Global.options(3)
			&"target":
				if Input.is_action_just_pressed(Global.cancel()):
					_on_back_pressed()
				if Input.is_action_just_pressed("ui_down") and active:
					move_target(Vector2.DOWN)
				if Input.is_action_just_pressed("ui_up") and active:
					move_target(Vector2.UP)
				if Input.is_action_just_pressed("ui_left") and active:
					move_target(Vector2.LEFT)
				if Input.is_action_just_pressed("ui_right") and active:
					move_target(Vector2.RIGHT)
			&"ability":
				if Input.is_action_just_pressed(Global.cancel()):
					Bt.anim()
					Global.cancel_sound()
					root.emit()
				if Input.is_action_just_pressed("ui_up") and active:
					if %AbilityList.get_child_count() == 1:
						Global.buzzer_sound()
						return
					if MenuIndex != 0:
						MenuIndex -= 1
					else:
						MenuIndex = %AbilityList.get_child_count() - 1
					Global.cursor_sound()
					move_menu()
				if Input.is_action_just_pressed("ui_down") and active:
					if %AbilityList.get_child_count() == 1:
						Global.buzzer_sound()
						return
					if MenuIndex != %AbilityList.get_child_count() - 1:
						MenuIndex += 1
					else:
						MenuIndex = 0
					Global.cursor_sound()
					move_menu()
				if foc == null or not foc.has_meta("Ability"): return
				var ab: Ability = foc.get_meta("Ability")
				var abgroup: Array = foc.get_meta("AbilityGroup")
				if Input.is_action_just_pressed("ui_right") and active:
					if abgroup.find(ab) + 1 < abgroup.size():
						foc.set_meta("Ability", abgroup[abgroup.find(ab) + 1])
						move_menu()
						Global.cursor_sound()
				if Input.is_action_just_pressed("ui_left") and active:
					if abgroup.find(ab) != 0:
						foc.set_meta("Ability", abgroup[abgroup.find(ab) - 1])
						move_menu()
						Global.cursor_sound()
			&"command":
				if Input.is_action_just_pressed(Global.cancel()):
					Global.cancel_sound()
					emit_signal(PrevStage)
				if Input.is_action_just_pressed("LeftTrigger") and Bt.Seq.CanEscape:
					_on_escape()
				if Input.is_action_just_pressed(&"ui_accept"):
					analyze.emit()
			&"item":
				if Input.is_action_just_pressed(Global.cancel()):
					Global.cancel_sound()
					emit_signal(PrevStage)
			&"analyze":
				if Input.is_action_just_pressed(Global.cancel()):
					Global.cancel_sound()
					emit_signal(PrevStage)


func set_controller_icons() -> void:
	if stage != "ability":
		$Ability.icon = Global.get_controller().AbilityIcon
	$Attack.icon = Global.get_controller().AttackIcon
	if stage != "item":
		$Item.icon = Global.get_controller().ItemIcon
	$Command.icon = Global.get_controller().CommandIcon
	canvas.get_node("Confirm").icon = Global.get_controller().ConfirmIcon
	canvas.get_node("Back").icon = Global.get_controller().CancelIcon
	canvas.get_node("Give").icon = Global.get_controller().ItemIcon
	$DescPaper/ShowWheel.icon = Global.get_controller().CommandIcon
	Bt.get_node("Canvas/TurnOrder").icon = Global.get_controller().Select
	Bt.get_node("Canvas/TurnOrder/Options").icon = Global.get_controller().Start
	$CommandMenu/Escape.icon = Global.get_controller().LZ
	$CommandMenu/Analyze.icon = Global.get_controller().ConfirmIcon
	$CommandMenu/Strategize.icon = Global.get_controller().ItemIcon
	$Inventory/Cbutton.icon = Global.get_controller().R
	$Inventory/BIbutton.icon = Global.get_controller().L


func _on_root() -> void:
	if is_instance_valid(foc):
		foc.hide()
		foc.show()
	if is_instance_valid(t):
		t.kill()
	if is_instance_valid(trw):
		trw.kill()

	PrevStage = &"root"
	stage = &"root"

	PartyUI.battle_state()
	set_controller_icons()
	Bt.get_node("EnemyUI").all_enemy_ui()

	animation.play("RESET")
	Bt.move_cam(Vector2.ZERO, 0.3)
	Bt.zoom(4, 0.3)
	move_to(CurrentChar.node.position)

	CurrentChar.NextMove = null
	CurrentChar.NextTarget = null
	tweendone = false
	active = true
	analyzing = false

	$Attack.show()
	$Item.show()
	$Command.show()
	$Ability.show()
	$Item.mouse_filter = MouseFilter.MOUSE_FILTER_STOP
	$Ability.mouse_filter = MouseFilter.MOUSE_FILTER_STOP
	$Command.mouse_filter = MouseFilter.MOUSE_FILTER_STOP
	$Attack.mouse_filter = MouseFilter.MOUSE_FILTER_STOP

	if stage == "root":
		$DescPaper.hide()
		$CommandMenu.hide()
		$Inventory.hide()
	rooted.emit()


func _on_attack() -> void:
	Global.confirm_sound()
	stage = "attack"
	PrevStage = "root"
	CurrentChar.NextAction = "Attack"
	CurrentChar.NextMove = CurrentChar.StandardAttack
	get_target(Bt.get_oposing_faction())


func _on_ability() -> void:
	if CurrentChar.Abilities.is_empty(): return
	stage = &"ability"
	PrevStage = &"root"

	canvas.get_node("Confirm").text = "Confirm"
	canvas.get_node("Back").text = "Back"
	CurrentChar.NextAction = "Ability"

	PartyUI.only_current()
	Global.confirm_sound()

	$Ability.icon = null
	move_to(CurrentChar.node.position)
	Bt.zoom(4.5, 0.5, Tween.EASE_IN_OUT)
	Bt.move_cam(CurrentChar.node.position + Vector2(80, 0), 0.5)

	animation.play("ability")

	$Ability.focus_mode = 0
	$Ability.mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE

	if get_node_or_null("%AbilityList/Item" + str(MenuIndex)) == null:
		MenuIndex = 0

	await get_tree().physics_frame

	%AbilityList.get_child(MenuIndex).grab_focus()
	var color: Color = Abilities[MenuIndex].WheelColor
	if Abilities[MenuIndex].ColorSameAsActor: color = CurrentChar.MainColor
	$DescPaper/Title.add_theme_color_override("font_color", color - Color(0.2, 0.2, 0.2, 0))
	$DescPaper/Desc.text = Colorizer.colorize(Abilities[0].description)
	if Abilities[0].AuraCost != 0:
		$DescPaper/Cost.text = str("Cost ", str(Abilities[0].AuraCost))
		$DescPaper/Cost.show()
	else:
		$DescPaper/Cost.hide()
	$DescPaper/Title.text = Abilities[foc.get_index()].name
	CurrentChar.NextMove = CurrentChar.get_abilities()[foc.get_index()]
	await animation.animation_finished
	move_menu()


func _on_command() -> void:
	stage = &"inactive"
	PrevStage = &"root"

	Bt.get_node("Canvas/Back").text = "Back"
	CurrentChar.NextAction = "Command"
	analyzing = false
	animation.play("command")

	Global.confirm_sound()

	move_to(CurrentChar.node.position)
	Bt.zoom(5.5, 0.3)
	Bt.move_cam(CurrentChar.node.position + Vector2(-30, 0), 0.3)

	if not Bt.Seq.CanEscape:
		$CommandMenu/Escape.modulate = Color(1, 1, 1, 0.6)
	else:
		$CommandMenu/Escape.modulate = Color(1, 1, 1, 1)

	await Event.wait()
	stage = &"command"


func _on_item() -> void:
	PrevStage = &"root"
	stage = &"pre_item"
	if Item.ConInv.is_empty() and Item.BtiInv.is_empty(): $Item.disabled = true; return

	Bt.get_node("Canvas/Back").text = "Back"
	Bt.get_node("Canvas/Give").text = "Give"
	Bt.get_node("Canvas/Confirm").text = "Use"

	CurrentChar.NextAction = "Item"
	CurrentChar.NextMove = null
	CurrentChar.NextTarget = null
	$Item.icon = null
	$Item.mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE
	move_to(CurrentChar.node.position)
	animation.play("item")
	Global.confirm_sound()
	Bt.get_node("EnemyUI").colapse_root()
	Bt.zoom(5.5, 0.3)
	Bt.move_cam(CurrentChar.node.position + Vector2(-80, 0), 0.3)

	PartyUI.only_current()

	await get_tree().physics_frame

	if not %BattleItems.get_children().is_empty():
		%BattleItems.get_child(0).grab_focus()
	elif not %Consumables.get_children().is_empty():
		%Consumables.get_child(0).grab_focus()
	stage = &"item"


func close() -> void:
	active = false
	if stage == "target" and animation.is_playing() and animation.assigned_animation == "target":
		await animation.animation_changed
	PartyUI.battle_state()
	stage = &"inactive"
	animation.play("close")


func show_aoe_indicator(chara: Actor) -> void:
	var dub: TextureRect = $BaseRing/Ring2.duplicate()
	if char != null:
		dub.material = dub.material.duplicate()
		dub.set_instance_shader_parameter("circle_thickness", 0.04)
		var texture: GradientTexture1D = dub.texture.duplicate(true)
		texture.gradient.colors[0].v = texture.gradient.colors[0].v - 0.4
		dub.texture = texture
		dub.scale = Vector2(0.17, 0.17)
		dub.position = Vector2.ZERO - dub.get_combined_pivot_offset()
		chara.node.add_child(dub)
		while stage == "target":
			await Event.wait()
		dub.queue_free()


func _on_ability_pressed() -> void:
	ability.emit()


func _on_attack_pressed() -> void:
	attack.emit()


func _on_item_pressed() -> void:
	item.emit()


func _on_command_pressed() -> void:
	command.emit()


func get_target(faction: Array[Actor], ab := CurrentChar.NextMove) -> void:
	if faction.is_empty(): return
	if Bt.Action: return

	active = true
	if is_instance_valid(foc):
		foc.hide()
		foc.show()
	if Troop.is_empty():
		close()
		Bt.victory()
		return

	CurrentChar.NextMove = ab
	stage = &"target"

	TargetFaction = faction
	if CurrentChar.NextTarget != null and CurrentChar.NextTarget in faction and not analyzing:
		stage = &"inactive"
		close()
		Bt.confirm_next()
		return

	var back: Button = canvas.get_node("Back")
	var confirm: Button = canvas.get_node("Confirm")
	var attack_title: Button = canvas.get_node("AttackTitle")
	var wheel: Wheel = attack_title.get_node("Wheel")

	back.show()
	back.text = "Cancel"
	confirm.show()
	confirm.text = "Target"

	if ab != null:
		wheel.show_atk_color(ab.WheelColor)
		if (CurrentChar.NextAction != "Attack" and ab.WheelColor.s > 0
		and ab.Damage != Ability.D.NONE):
			wheel.show()
			wheel.show_atk_color(ab.WheelColor)
		else:
			wheel.hide()
		attack_title.get_node("RichTextLabel").text = Colorizer.colorize(ab.description)
		attack_title.text = ab.name
		attack_title.icon = ab.Icon

	if LastTarget == null or not LastTarget in faction:
		LastTarget = CurrentTarget
	CurrentTarget = LastTarget
	if (CurrentTarget not in faction):
		CurrentTarget = faction[0]

	if analyzing:
		wheel.show()
		wheel.show_atk_color(CurrentTarget.MainColor)
		move_menu()

	animation.play("target")

	move_to(CurrentTarget.node.position)
	Bt.move_cam(get_target_pos(CurrentTarget), 0.5)
	Bt.zoom(4.5, 0.6)

	emit_signal('targetFoc', CurrentTarget)
	wheel.show_trg_color(CurrentTarget.MainColor)
	PartyUI.show_all()


func get_target_pos(tar: Actor) -> Vector2:
	return Vector2(tar.node.position.x, tar.node.position.y / 4)


func _on_ability_returned(ab: Ability, tar: Actor) -> void:
	close()


func move_menu() -> void:
	await Event.wait()
	foc = get_viewport().gui_get_focus_owner()
	if stage == &"target":
		if LastTarget == CurrentTarget: return
		active = false

		if CurrentTarget.node == null:
			Bt.fix_enemy_node_issues()
			move_menu()
			return

		Global.cursor_sound()

		Bt.move_cam(Vector2(CurrentTarget.node.position.x, CurrentTarget.node.position.y / 4), 0.5)
		LastTarget = CurrentTarget
		move_to(CurrentTarget.node.position)
		emit_signal('targetFoc', CurrentTarget)

		var wheel: Wheel = canvas.get_node("AttackTitle/Wheel")

		if analyzing:
			wheel.show_atk_color(CurrentTarget.MainColor)
			await Event.wait()
			wheel.show_trg_color(CurrentTarget.MainColor)
			canvas.get_node("AttackTitle/RichTextLabel").text = "HP: %d		AP: %d\nAttack: %.1f \nDefence: %.1f \nMagic: %.1f " % [
				CurrentTarget.MaxHP,
				CurrentTarget.MaxAura,
				CurrentTarget.Attack,
				CurrentTarget.Defence,
				CurrentTarget.Magic
			]
			canvas.get_node("AttackTitle").icon = CurrentTarget.PartyIcon
			canvas.get_node("AttackTitle").text = CurrentTarget.FirstName
		else:
			wheel.show_trg_color(CurrentTarget.MainColor)
		await get_tree().create_timer(0.1).timeout
		active = true
	if stage == &"ability":
		if foc == null: return
		if not foc.has_meta("Ability"): return
		if not foc.has_meta("AbilityGroup"): return
		active = false
		if not is_instance_valid(foc): return
		var abgroup: Array = foc.get_meta("AbilityGroup")
		var ab: Ability = foc.get_meta("Ability")
		update_ab(foc)

		var rankswap: Control = foc.get_node("RankSwap")
		if rankswap != null:
			if abgroup.size() == 1:
				rankswap.get_node("AnimationPlayer").play("arrows")
			rankswap.get_node("Left").visible = (abgroup.find(ab) != 0)
			rankswap.get_node("Right").visible = (abgroup.find(ab) != abgroup.size() - 1)
		else:
			pass

		if not %AbilityList.get_child(MenuIndex).has_focus():
			%AbilityList.get_child(MenuIndex).grab_focus()
		$DescPaper/Desc.text = Colorizer.colorize(ab.description)
		var color: Color = ab.WheelColor
		if ab.ColorSameAsActor or color == Color.WHITE: color = CurrentChar.MainColor
		$DescPaper/Title.add_theme_color_override("font_color",
		color - Color(0.2, 0.2, 0.2, 0))
		$DescPaper/Title.text = ab.name
		CurrentChar.NextMove = foc.get_meta("Ability")
		if ab.AuraCost != 0:
			$DescPaper/Cost.text = str("Cost ", str(ab.AuraCost))
			$DescPaper/Cost.show()
		else:
			$DescPaper/Cost.hide()
		if CurrentChar.NextMove.WheelColor.s > 0 and CurrentChar.NextMove.Damage != Ability.D.NONE:
			$DescPaper/ShowWheel.show()
			$DescPaper/ShowWheel/Wheel.show_atk_color(CurrentChar.NextMove.WheelColor)
		else:
			$DescPaper/ShowWheel.hide()
		if (
			ab.AuraCost > CurrentChar.Aura or ab.disabled or
			(CurrentChar.has_state("Bound") and ab.Damage == Ability.D.WEAPON)
		):
			if ab.AuraCost > CurrentChar.Aura:
				foc.get_node("Label").add_theme_color_override("font_color", Color(1, 0.25, 0.32, 0.5))
			foc.disabled = true
		else:
			foc.disabled = false
			foc.get_node("Label").remove_theme_color_override("font_color")
	active = true
	tweendone = true


func move_target(direction: Vector2) -> void:
	var best_target: Actor = CurrentTarget
	var closest_distance := INF

	for tar in TargetFaction:
		if tar == CurrentTarget: continue

		var distance_from_current := tar.node.position - CurrentTarget.node.position
		var dot := distance_from_current.normalized().dot(direction)

		# Dot product > 0.5 means the CurrentTarget is within a 45-degree cone in that direction
		if dot > 0.4:
			var dist := distance_from_current.length()
			if dist < closest_distance:
				closest_distance = dist
				best_target = tar

	CurrentTarget = best_target
	move_menu()


func _on_battle_next_turn() -> void:
	if CurrentChar == null: return
	if not Bt.CurrentChar.Controllable:
		hide()
		active = false


func _on_targeted() -> void:
	if analyzing:
		Global.member_details(CurrentChar.NextTarget)
		stage = "analyze"
		PrevStage = "analyze"
	elif CurrentChar.NextAction == "ItemGive":
		give_item(given_item)
	else:
		PrevStage = "targeted"
		if CurrentChar.NextMove == null: return
		if CurrentChar.NextTarget == null or CurrentChar.NextTarget not in TargetFaction:
			CurrentChar.NextTarget = CurrentTarget
		#stage = "inactive"
		if CurrentChar.has_state("Confused") and randi_range(0, 5) > 0:
			var proper_tar: Actor = CurrentTarget
			TargetFaction = Bt.get_any_faction()
			CurrentTarget = TargetFaction.pick_random()
			while CurrentTarget == proper_tar:
				CurrentTarget = TargetFaction.pick_random()
			CurrentChar.NextTarget = CurrentTarget
			await move_menu()
			Bt.confusion_msg()
		Bt.confirm_next(false)
		close()


func _on_back_pressed() -> void:
	Global.cancel_sound()
	emit_signal(PrevStage)


func _on_focus_changed(control: Control) -> void:
	# Existing foc unfocus actions
	if is_instance_valid(foc):
		# Hide rankswap buttons on an ability button when losing focus
		if foc.has_node("RankSwap"):
			foc.get_node("RankSwap/Left").hide()
			foc.get_node("RankSwap/Right").hide()

	foc = control
	# New foc actions
	if control is Button:
		MenuIndex = control.get_index()
		move_menu()
		if stage == &"item" or &"pre_item":
			if stage == &"item": Global.cursor_sound()
			focus_item(control)


func _on_ability_entry() -> void:
	if active:
		active = false
		Global.confirm_sound()
		var ab: Ability = %AbilityList.get_child(MenuIndex).get_meta("Ability")
		match ab.Target:
			Ability.T.ONE_ENEMY:
				PrevStage = "ability"
				stage = &"target"
				get_target(Bt.get_oposing_faction())
			Ability.T.ONE_ALLY:
				PrevStage = "ability"
				stage = &"target"
				get_target(Bt.get_ally_faction(CurrentChar, !ab.CanTargetDead))
			Ability.T.ANY:
				PrevStage = "ability"
				stage = &"target"
				get_target(Bt.get_any_faction(!ab.CanTargetDead))
			Ability.T.AOE_ALLIES:
				PrevStage = "ability"
				stage = &"target"
				var fact := Bt.get_ally_faction(CurrentChar, !ab.CanTargetDead)
				for i in fact:
					show_aoe_indicator(i)
				get_target(fact)
			Ability.T.AOE_ENEMIES:
				PrevStage = "ability"
				stage = &"target"
				var fact := Bt.get_oposing_faction(CurrentChar, !ab.CanTargetDead)
				for i in fact:
					show_aoe_indicator(i)
				get_target(fact)
			_:
				CurrentChar.NextTarget = CurrentChar
				CurrentChar.NextMove = ab
				Bt.confirm_next(false)
				close()


func _on_confirm_pressed() -> void:
	if active:
		if stage == &"target":
			Global.confirm_sound()
			CurrentChar.NextTarget = CurrentTarget
			targeted.emit()
		if stage == &"item":
			Global.confirm_sound()
			use_item()


func use_item() -> void:
	if foc == null or !foc.has_meta("ItemData") or foc.get_meta("ItemData") == null: return
	elif foc is Button and foc.get_meta("ItemData").UsedInBattle:
		var aitem: ItemData = foc.get_meta("ItemData")
		aitem.BattleEffect.name = aitem.Name
		aitem.BattleEffect.description = aitem.Description
		aitem.BattleEffect.Icon = aitem.Icon
		aitem.BattleEffect.remove_item_on_use = foc.get_meta("ItemData")
		PrevStage = &"item"
		CurrentChar.NextAction = "Item"
		if aitem.BattleEffect.Target == Ability.T.SELF or aitem.BattleEffect.Target == Ability.T.ONE_ALLY:
			CurrentChar.NextMove = aitem.BattleEffect
			get_target([CurrentChar])
		if aitem.BattleEffect.Target == Ability.T.ONE_ENEMY:
			CurrentChar.NextMove = aitem.BattleEffect
			get_target(Bt.get_oposing_faction())


func turn_order() -> void:
	Bt.get_node("Canvas/TurnOrderPop").show()
	t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel()
	t.tween_property(Bt.get_node("Canvas/TurnOrder/Options"), "position:y", 0, 0.2)
	t.tween_property(Bt.get_node("Canvas/TurnOrderPop"), "modulate", Color.WHITE, 0.3)
	t.tween_property(Bt.get_node("Canvas/TurnOrderPop"), "position", Vector2(52, 40), 0.3)

	while (Input.is_action_pressed("PartyMenu") or Bt.get_node("Canvas/TurnOrder").button_pressed):
		Bt.turn_ui_check()
		await Event.wait()

	t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_parallel()
	t.tween_property(Bt.get_node("Canvas/TurnOrder/Options"), "position:y", -60, 0.2)
	t.tween_property(Bt.get_node("Canvas/TurnOrderPop"), "modulate", Color.TRANSPARENT, 0.3)
	t.tween_property(Bt.get_node("Canvas/TurnOrderPop"), "position", Vector2(-468, 40), 0.3)


func _on_escape() -> void:
	if stage == &"command":
		stage = &"inactive"
		Bt.escape()


func _on_show_wheel_pressed() -> void:
	Global.confirm_sound()
	t = create_tween()
	t.set_ease(Tween.EASE_IN_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_parallel()
	if $DescPaper/ShowWheel/Wheel.visible:
		Bt.get_node("EnemyUI").all_enemy_ui()
		$DescPaper/ShowWheel.text = "Show wheel"
		t.tween_property($DescPaper/ShowWheel, "position:x", 150, 0.3)
		t.tween_property($DescPaper/ShowWheel/Wheel, "modulate", Color.TRANSPARENT, 0.3)
		await t.finished
		$DescPaper/ShowWheel/Wheel.hide()
	else:
		Bt.get_node("EnemyUI").colapse_root()
		$DescPaper/ShowWheel/Wheel.show()
		$DescPaper/ShowWheel.text = "Hide"
		$DescPaper/ShowWheel.size.x = 1
		t.tween_property($DescPaper/ShowWheel/Wheel, "modulate", Color.WHITE, 0.3).from(Color.TRANSPARENT)
		t.tween_property($DescPaper/ShowWheel, "position:x", 520, 0.3)


func fetch_inventory() -> void:
	Item.verify_inventory()
	var inventory_grid: Dictionary[String, GridContainer] = {
		"con": %Consumables,
		"bti": %BattleItems,
	}
	for inv in inventory_grid:
		for i in inventory_grid[inv].get_children():
			i.free()
		for aitem in Item.get_inv(inv):
			if aitem.UsedInBattle:
				var dub: Control = %Item.duplicate()
				dub.icon = aitem.Icon
				dub.set_meta("ItemData", aitem)
				if aitem.Quantity > 1:
					dub.text = str(aitem.Quantity)
				else: dub.text = ""
				inventory_grid[inv].add_child(dub)
				dub.show()

	await Event.wait()

	if inventory_grid["bti"].get_children().is_empty():
		$Inventory/BIbutton.disabled = true
		%BattleItems.hide()
		%BtiLabel.hide()
	if inventory_grid["con"].get_children().is_empty():
		$Inventory/Cbutton.disabled = true
		%Consumables.hide()
		%ConLabel.hide()
	if $Inventory/Cbutton.disabled and $Inventory/BIbutton.disabled:
		$Item.disabled = true
		return


func fetch_abilities() -> void:
	for n in %AbilityList.get_children():
		%AbilityList.remove_child(n)
		n.queue_free()
	for i in CurrentChar.groupped_abilities():
		var dub: Button = %Ab0.duplicate()
		dub.show()
		%AbilityList.add_child(dub)
		dub.set_meta("AbilityGroup", i)
		var ab: Ability = i[0]
		dub.set_meta("Ability", ab)
		var rankswap: Control = dub.get_node("RankSwap")
		rankswap.get_node("Left").hide()
		rankswap.get_node("Right").hide()
		update_ab(dub)
	for i in %AbilityList.get_children():
		if (
			i.get_meta("Ability").AuraCost > CurrentChar.Aura or i.get_meta("Ability").disabled or
			(CurrentChar.has_state("Bound") and i.get_meta("Ability").Damage == Ability.D.WEAPON)
		):
			if i.get_meta("Ability").AuraCost > CurrentChar.Aura:
				i.get_node("Label").add_theme_color_override("font_color", Color(1, 0.25, 0.32, 0.5))
			i.disabled = true
			%AbilityList.get_children().push_back(i)


func update_ab(dub: Button) -> void:
	var ab: Ability = dub.get_meta("Ability")
	dub.text = ab.name
	if dub is WaveButton:
		if ab.ColorSameAsActor:
			dub.theme_color = CurrentChar.MainColor
		else:
			dub.theme_color = ab.WheelColor
	dub.get_node("Icon").texture = ab.Icon
	var label: Label = dub.get_node("Label")
	if ab.AuraCost != 0:
		label.text = str(ab.AuraCost)
		label.show()
	else:
		dub.get_child(0).hide()
	dub.name = "Item" + str(dub.get_index(true))
	dub.set_meta("Ability", ab)


func _on_b_ibutton_pressed(tog: bool) -> void:
	if "item" in stage:
		if %BIbutton.disabled:
			Global.buzzer_sound(); return
		else:
			%BattleItems.get_child(0).grab_focus()


func _on_cbutton_pressed(tog: bool) -> void:
	if "item" in stage:
		if %Cbutton.disabled:
			Global.buzzer_sound(); return
		else:
			%Consumables.get_child(0).grab_focus()


func focus_item(node: Button) -> void:
	if not node.get_parent() is GridContainer: return
	if not node.has_meta("ItemData"): return
	var item_data: ItemData = node.get_meta("ItemData")
	$Inventory/DescPaper/Title.text = item_data.Name
	$Inventory/DescPaper/Desc.text = Colorizer.colorize(item_data.Description)
	$Inventory/DescPaper/Art.texture = item_data.Artwork
	if item_data.Quantity > 1:
		$Inventory/DescPaper/Amount.text = str(item_data.Quantity) + " in bag"
		$Inventory/DescPaper/Amount.show()
	else:
		$Inventory/DescPaper/Amount.hide()
	if not item_data.UsedInBattle:
		canvas.get_node("Confirm").hide()
	elif item_data.Use == ItemData.U.INSPECT:
		canvas.get_node("Confirm").show()
		canvas.get_node("Confirm").text = "Inspect"
	else:
		canvas.get_node("Confirm").show()
		canvas.get_node("Confirm").text = "Use"

	%BIbutton.set_pressed_no_signal(node.get_parent() == %BattleItems)
	%Cbutton.set_pressed_no_signal(node.get_parent() == %Consumables)

var given_item: ItemData


func _on_give_pressed() -> void:
	if stage == "item":
		if foc == null or not foc.has_meta("ItemData"):
			return
		Global.confirm_sound()
		CurrentChar.NextMove = null
		CurrentChar.NextAction = "ItemGive"
		var item_dat: ItemData = foc.get_meta("ItemData")
		item_dat.BattleEffect.name = item_dat.Name
		item_dat.BattleEffect.description = item_dat.Description
		item_dat.BattleEffect.Icon = item_dat.Icon
		PrevStage = &"item"
		given_item = item_dat

		var faction := Bt.get_ally_faction().duplicate()
		faction.erase(CurrentChar)
		get_target(faction, item_dat.BattleEffect)


func give_item(item_dat: ItemData = given_item) -> void:
	if PrevStage == "root": return
	if CurrentTarget != null:
		Bt.CurrentTarget = CurrentTarget
		if CurrentTarget.NextAction == "":
			close()
			Bt.focus_cam(CurrentTarget)
			Bt.zoom(5)
			CurrentTarget.NextAction = "Item"
			CurrentTarget.NextMove = item_dat.BattleEffect
			Item.remove_item(item_dat)
			Bt.battle_msg("use_on_turn", item_dat.Name)
			await Event.wait(1)
			fetch_inventory()
			root.emit()
			Global.ui_sound("expand")
			CurrentChar.NextAction = ""
			CurrentChar.NextMove = null
			CurrentChar.NextTarget = null
		else:
			Bt.battle_msg("busy", CurrentTarget.FirstName)


func _analyze() -> void:
	analyzing = true
	PrevStage = &"command"
	await Event.wait()
	get_target(Bt.get_any_faction())


func _on_options_pressed() -> void:
	if stage == "root":
		Global.options()
