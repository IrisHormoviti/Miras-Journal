extends CanvasLayer

var chara: Actor
var slots: int
var setting := false
var active_slot: int = 0


func _init() -> void:
	hide()


func draw_character(character: Actor) -> void:
	chara = character
	##Test
	#Global.Complimentaries = ["FluidBlast", "RedShift", "Dispel"]
	#chara.SkillLevel = 10
	#chara.ComplimentaryList = {"FluidBlast":1, "RedShift":1}

	slots = chara.SkillLevel / 10 + 1
	await chara.load_complimentaries()
	await fetch_equiped_abilities()
	await fetch_all_abilities()
	for i in slots - 1:
		var grd: TextureRect = $Background.get_child(0).duplicate()
		grd.set_meta("rate", randf_range(-0.1, 0.1))
		$Background.add_child(grd)
		grd.rotation_degrees = randf_range(0, 360)
	for i in $Background.get_children(): i.modulate = Color.TRANSPARENT
	$Background.self_modulate = Color.TRANSPARENT
	$Title/Member.text = "[img width=58]%s[/img] %s %s" % [chara.PartyIcon.resource_path, chara.FirstName, chara.LastName]
	refresh()
	show()
	%Equipped.get_child(0).grab_focus()
	Audio.confirm_sound()

	var t := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	t.tween_property($Title, "modulate", Color.WHITE, 0.9).from(Color.TRANSPARENT)
	t.tween_property($Title, "scale", Vector2.ONE, 0.9).from(Vector2(0.8, 0.8))
	t.tween_property($Desc, "modulate", Color.WHITE, 0.8).from(Color.TRANSPARENT)
	t.tween_property($Desc, "scale", Vector2.ONE, 0.8).from(Vector2(0.8, 0.8))
	t.tween_property($Equipped, "modulate", Color.WHITE, 0.5).from(Color.TRANSPARENT)
	t.tween_property($Equipped, "scale", Vector2(1.3, 1.3), 0.5).from(Vector2(1.7, 1.7))
	t.tween_property($Sines, "modulate", Color.WHITE, 0.5).from(Color.TRANSPARENT)
	t.tween_property($Sines, "scale", Vector2(1, 1), 0.5).from(Vector2(1.5, 1.5))


func fetch_all_abilities() -> void:
	var Abilities := await Query.get_complimentaries()
	for n in %AbilityList.get_children():
		if n is Button:
			%AbilityList.remove_child(n)
			n.queue_free()
	for i in Abilities:
		var dub: Button = %Ab0.duplicate()
		dub.show()
		%AbilityList.add_child(dub)
		dub.text = i.name
		dub.get_node("Icon").texture = i.Icon
		if i.AuraCost != 0:
			dub.get_child(0).text = str(i.AuraCost)
			dub.get_child(0).show()
		else:
			dub.get_child(0).hide()
		dub.name = "Item" + str(dub.get_index(true))
		dub.set_meta("Ability", i)


func fetch_equiped_abilities() -> void:
	await chara.load_complimentaries()
	while chara.Complimentaries.size() > slots:
		chara.Complimentaries.remove_at(-1)
	var Abilities := chara.Complimentaries
	while slots > %Equipped.get_child_count():
		var dub: Button = %Slot0.duplicate()
		dub.show()
		%Equipped.add_child(dub)
		dub.disabled = true
	var j := 0
	for i in Abilities:
		var dub: Button = $Equipped.get_child(j)
		dub.set_meta("Ability", i)
		j += 1
	update_equipped()


func update_equipped() -> void:
	for dub in $Equipped.get_children():
		if dub.has_meta("Ability"):
			var i: Ability = dub.get_meta("Ability")
			dub.disabled = false
			dub.text = i.name
			dub.get_node("Icon").texture = i.Icon
			if i.AuraCost != 0:
				dub.get_child(0).text = str(i.AuraCost)
				dub.get_child(0).show()
			else:
				dub.get_child(0).hide()
			dub.name = "Item" + str(dub.get_index(true))


func refresh() -> void:
	$Set.icon = Controller.get_scheme().ConfirmIcon
	$Back.icon = Controller.get_scheme().CancelIcon
	for i in %AbilityList.get_children():
		if not i is Button: continue
		if i.get_meta("Ability") in chara.Complimentaries:
			i.disabled = true
		else: i.disabled = false
	var t := create_tween().set_parallel().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUART)
	t.tween_property($Background, "self_modulate", chara.MainColor, 0.3)
	for i in $Background.get_child_count():
		if chara.Complimentaries.size() <= i:
			t.tween_property($Background.get_child(i), "modulate", Color.TRANSPARENT, 1)
		else:
			var color := chara.Complimentaries[i].WheelColor
			if chara.Complimentaries[i].WheelColor == Color.WHITE: color.a = 0.3
			else: color.a = 0.6
			t.tween_property($Background.get_child(i), "modulate", color, randf_range(0.5, 3))


func _on_list_focus_entered() -> void:
	Audio.cursor_sound()
	var ab: Ability = get_viewport().gui_get_focus_owner().get_meta("Ability")
	if not is_instance_valid(ab): return
	if ab.WheelColor != Color.WHITE and not ab.ColorSameAsActor and ab.Damage != Ability.D.NONE:
		%Wheel.show()
		%Wheel.color = ab.WheelColor
		%Wheel.draw_wheel()
		%Wheel.draw_wheel()
	else: %Wheel.hide()
	%AttackTitle.text = ab.name
	%AttackTitle/RichTextLabel.text = Colorizer.colorize(ab.description)


func _on_equipped_focus_entered() -> void:
	#refresh()
	Audio.cursor_sound()
	var foc := get_viewport().gui_get_focus_owner()
	if foc.has_meta("Ability"):
		var ab: Ability = foc.get_meta("Ability")
		if not is_instance_valid(ab): return
		if ab.WheelColor != Color.WHITE and not ab.ColorSameAsActor and ab.Damage != Ability.D.NONE:
			$Desc/Wheel.show()
			$Desc/Wheel.color = ab.WheelColor
			$Desc/Wheel.draw_wheel()
			$Desc/Wheel.draw_wheel()
		else: $Desc/Wheel.hide()
		$Desc/RichTextLabel.text = Colorizer.colorize(ab.description)
	else:
		$Desc/RichTextLabel.text = "This slot is empty.\n\nPress [img width=48]" + Controller.get_scheme().ConfirmIcon.resource_path + "[/img] to equip one of the available Complimentary abilities to this slot."
		$Desc/Wheel.hide()


func _process(delta: float) -> void:
	for i: TextureRect in $Background.get_children():
		i.rotation_degrees += i.get_meta("rate")


func _on_back_pressed() -> void:
	if $AbilityPanel.visible:
		$AbilityPanel.hide()
		$Equipped.get_child(active_slot).grab_focus()
	else:
		if UI.is_open("MemberDetails"):
			UI.get_node("MemberDetails").fetch_abilities(chara)
			UI.get_node("MemberDetails/AbilityPanel/Border1/Scroller/AbilityList").get_child(1).grab_focus()
		Audio.cancel_sound()

		var t := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		t.tween_property($Title, "modulate", Color.TRANSPARENT, 0.3)
		t.tween_property($Title, "scale", Vector2(0.8, 0.8), 0.3)
		t.tween_property($Desc, "modulate", Color.TRANSPARENT, 0.3)
		t.tween_property($Desc, "scale", Vector2(0.8, 0.8), 0.3)
		t.tween_property($Equipped, "modulate", Color.TRANSPARENT, 0.3)
		t.tween_property($Equipped, "scale", Vector2(2, 2), 0.3)
		t.tween_property($Sines, "modulate", Color.TRANSPARENT, 0.3)
		t.tween_property($Sines, "scale", Vector2(1.5, 1.5), 0.3)
		t.tween_property($Background, "modulate", Color.TRANSPARENT, 0.3)
		await t.finished
		UI.get_node("MemberDetails").inactive = false
		queue_free()


func set_ability(slot: int) -> void:
	active_slot = slot
	$AbilityPanel.show()
	refresh()
	%AbilityList.get_child(0).grab_focus()


func _set_pressed() -> void:
	if $AbilityPanel.visible:
		_list_ability_pressed()
	else:
		_on_slot_pressed()


func _on_slot_pressed() -> void:
	var foc := get_viewport().gui_get_focus_owner()
	await fetch_all_abilities()
	set_ability(foc.get_index())
	Audio.confirm_sound()


func _list_ability_pressed() -> void:
	var foc := get_viewport().gui_get_focus_owner()
	if foc.disabled:
		Audio.buzzer_sound()
	else:
		var ab: Ability = foc.get_meta("Ability")
		var slot: Button = $Equipped.get_child(active_slot)
		var prev_ab: Ability = slot.get_meta("Ability") if slot.has_meta("Ability") and slot.get_meta("Ability") != null else null
		if ab.filename in chara.ComplimentaryList:
			chara.ComplimentaryList.set(ab.filename, abs(chara.ComplimentaryList.get(ab.filename)))
		else: chara.ComplimentaryList.set(ab.filename, 1)
		if prev_ab != null:
			chara.ComplimentaryList.set(prev_ab.filename, -abs(chara.ComplimentaryList.get(prev_ab.filename)))

		slot.set_meta("Ability", ab)
		update_equipped()
		await chara.load_complimentaries()
		#await fetch_equiped_abilities()
		refresh()
		_on_back_pressed()
		Audio.confirm_sound()
