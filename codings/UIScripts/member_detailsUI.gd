extends CanvasLayer
var stability_menu := false
var actor: Actor
var inactive := false


func _ready() -> void:
	hide()


func draw_character(chara: Actor, menu := 0) -> void:
	if Global.complimentaries.is_empty():
		$AbilityPanel/Complimentary.disabled = true
		$AbilityPanel/Border1/Scroller/AbilityList/CompTxt.hide()
	else:
		$AbilityPanel/Complimentary.disabled = false

	actor = chara
	chara.load_complimentaries()
	Audio.confirm_sound()
	$Name/Icon.texture = chara.PartyIcon
	$Name.text = chara.FirstName + " " + chara.LastName

	if chara.SkillCurve != null:
		$StatPanel/LvBox/Vbox/LvBar/Number.text = str(chara.SkillLevel)
		$StatPanel/LvBox/Vbox/LvBar/SPNum.text = str(chara.SkillPoints)
		$StatPanel/LvBox/Vbox/ExpBar.max_value = chara.skill_points_for(chara.SkillLevel)
		$StatPanel/LvBox/Vbox/ExpBar.value = chara.SkillPoints
		$StatPanel/LvBox/Vbox/ToNextLv/Number.text = str(chara.skill_points_for(chara.SkillLevel) - chara.SkillPoints)

	$StatPanel/HPAura/HPText.text = str(chara.MaxHP)
	$StatPanel/HPAura/APText.text = str(chara.MaxAura)
	$StatPanel/HPAura/Health.max_value = 300
	$StatPanel/HPAura/Aura.max_value = 100
	$StatPanel/HPAura/Health.value = chara.MaxHP
	$StatPanel/HPAura/Aura.value = chara.MaxAura

	$StatPanel/HPAura/HPText.add_theme_color_override("font_color", chara.MainColor)
	$StatPanel/HPAura/APText.add_theme_color_override("font_color", chara.SecondaryColor)
	var hbox: StyleBoxFlat = $StatPanel/HPAura/Health.get_theme_stylebox("fill")
	hbox.bg_color = chara.MainColor
	$StatPanel/HPAura/Health.add_theme_stylebox_override("fill", hbox.duplicate())
	var abox: StyleBoxFlat = $StatPanel/HPAura/Aura.get_theme_stylebox("fill")
	abox.bg_color = chara.SecondaryColor
	$StatPanel/HPAura/Aura.add_theme_stylebox_override("fill", abox.duplicate())
	if chara.CharacterBoxProfile != null:
		var bord1: StyleBoxFlat = $StatPanel/Border1.get_theme_stylebox("panel")
		bord1.border_color = chara.CharacterBoxProfile.Bord1
		$StatPanel/Border1.add_theme_stylebox_override("panel", bord1.duplicate())
		var bord2: StyleBoxFlat = $StatPanel/Border1/Border2.get_theme_stylebox("panel")
		bord2.border_color = chara.CharacterBoxProfile.Bord2
		$StatPanel/Border1/Border2.add_theme_stylebox_override("panel", bord2.duplicate())
		var bord3: StyleBoxFlat = $StatPanel/Border1/Border2/Border3.get_theme_stylebox("panel")
		bord3.border_color = chara.CharacterBoxProfile.Bord3
		$StatPanel/Border1/Border2/Border3.add_theme_stylebox_override("panel", bord3.duplicate())

	#$StatPanel/LvBox/Vbox/ExpBar.add_theme_stylebox_override("fill", hbox.duplicate())
	#var xbox = hbox.duplicate()
	#xbox.bg_color = chara.BoxProfile.Bord3
	#$StatPanel/LvBox/Vbox/ExpBar.add_theme_stylebox_o]verride("background", xbox)

		$Line1.color = chara.CharacterBoxProfile.Bord1
		$Line1/Line2.color = chara.CharacterBoxProfile.Bord2
		$Line1/Line2/Line3.color = chara.CharacterBoxProfile.Bord3

	$StatPanel/StatBars/Attack.value = chara.Attack
	$StatPanel/StatBars/Defence.value = chara.Defence
	$StatPanel/StatBars/Magic.value = chara.Magic
	$StatPanel/Weapon/WeaponName.text = chara.Weapon.Name
	$StatPanel/Weapon/Icon.texture = chara.Weapon.Icon
	$StatPanel/Weapon/Icon/WeaponRating.text = "Power rating: " + Query.get_power_rating(chara.Weapon.power)

	$StatPanel/Wheel.color = chara.MainColor
	$StatPanel/Wheel.draw_wheel()
	$Render.texture = await Loader.load_res(chara.RenderArtwork) if not chara.RenderArtwork.is_empty() else null
	$Render/Shadow.texture = await chara.RenderShadow()
	$Render.global_position = Hud.get_node("%Pages/Page" + str(Hud.focus) + "/Render").global_position

	fetch_abilities(chara)

	for i in $Line1/NameChain.get_children():
		i.text = chara.FirstName.to_upper() + " " + chara.LastName.to_upper() + " "
		#i.add_theme_color_override("font_color", chara.BoxProfile.Bord3)

	await Event.wait(0.1, false)
	var anim: Animation = $AnimationPlayer.get_animation("scrollname")
	anim.track_set_key_value(0, 1, Vector2(-$Line1/NameChain/Name3.size.x, 130))
	$StatPanel/Wheel.draw_wheel()

	$Fade.hide()
	$Name.hide()
	$Abilities.hide()
	$Back.hide()
	$AbilityPanel.hide()
	$StatPanel.hide()
	$Back.icon = Controller.get_scheme().CancelIcon
	$Abilities.icon = Controller.get_scheme().ItemIcon

	swap_mode()
	show()
	var t := create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	#t.tween_property($Render, "modulate", Color.WHITE, 0.5).from(Color.TRANSPARENT)
	Hud.get_node("%Pages/Page" + str(Hud.focus) + "/Render").hide()
	t.tween_property($Render, "global_position", Vector2(587, -2), 0.8)
	t.tween_property($Render/Shadow, "modulate:a", 0.4, 0.6)
	t.tween_property($Render, "scale", Vector2(0.245, 0.245), 0.8).from(Vector2(0.215, 0.215))
	t.tween_property($Line1, "position:x", 750, 0.6).from(-2700)
	if menu == 1:
		swap_mode(true)

	await Event.wait(0.1, false)
	$Name.show()
	$Fade.show()
	$Abilities.show()
	$Back.show()


func swap_mode(stability := false) -> void:
	Audio.ui_sound("swap")
	stability_menu = stability

	match stability_menu:
		false:
			var t := create_tween()
			t.set_parallel()
			t.tween_property($AbilityPanel, "scale:x", 0, 0.1)
			t.tween_property($AbilityPanel, "position:x", 300, 0.1)
			await t.finished
			$StatPanel.show()
			$AbilityPanel.hide()
			$Abilities.text = "Abilities"
			t = create_tween()
			t.set_parallel()
			t.set_trans(Tween.TRANS_QUART)
			t.set_ease(Tween.EASE_OUT)
			t.tween_property($StatPanel, "position:x", 60, 0.1).from(300)
			t.tween_property($StatPanel, "scale:x", 1, 0.1).from(0.1)
			$Abilities.shortcut.events[0].action = "BtItem"
			$Abilities.icon = Controller.get_scheme().ItemIcon

		true:
			var t := create_tween()
			t.set_parallel()
			t.tween_property($StatPanel, "scale:x", 0, 0.1)
			t.tween_property($StatPanel, "position:x", 300, 0.1)
			await t.finished
			$StatPanel.hide()
			$AbilityPanel.show()
			$Abilities.text = "Stats"
			%AbilityList.get_child(1).grab_focus()
			t = create_tween()
			t.set_parallel()
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_QUART)
			t.tween_property($AbilityPanel, "position:x", 60, 0.1).from(300)
			t.tween_property($AbilityPanel, "scale:x", 1, 0.1).from(0.1)
			t.tween_property($AbilityPanel/AttackTitle, "position:x", 400, 0.5).from(0)
			$Abilities.shortcut.events[0].action = "BtCommand"
			$Abilities.icon = Controller.get_scheme().CommandIcon
			$AbilityPanel/Complimentary.icon = Controller.get_scheme().ConfirmIcon


func _on_back_pressed() -> void:
	if inactive: return
	Audio.cancel_sound()
	var t := create_tween()
	t.tween_property(self, "offset:x", -3500, 0.2)
	await Event.wait(0.1, false)
	$Fade.hide()
	$Name.hide()
	$Abilities.hide()
	$Back.hide()
	$AbilityPanel.hide()
	$StatPanel.hide()
	Hud.close_submenu()
	await Event.wait(0.1, false)
	queue_free()


func fetch_abilities(chara: Actor) -> void:
	var Abilities := chara.get_abilities()
	Abilities.push_front(chara.StandardAttack)
	for n in %AbilityList.get_children():
		if n is Button:
			%AbilityList.remove_child(n)
			n.queue_free()

	for i: Ability in Abilities:
		var dub: Control = %Ab0.duplicate()
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

	%AbilityList.move_child(%AbilityList/CompTxt, chara.Abilities.size() + 3)
	%AbilityList.move_child(%AbilityList/AbilitiesTxt, 2)


func _on_abilities_pressed() -> void:
	if inactive: return
	swap_mode(!stability_menu)


func _on_ab_focus_entered() -> void:
	if get_viewport().gui_get_focus_owner().get_index() == 1:
		$AbilityPanel/Border1/Scroller.scroll_vertical = 0

	if $AbilityPanel.scale == Vector2.ONE: Audio.cursor_sound()
	var ab: Ability = get_viewport().gui_get_focus_owner().get_meta("Ability")

	if not is_instance_valid(ab): return
	if ab.WheelColor != Color.WHITE and not ab.ColorSameAsActor and ab.Damage != Ability.D.NONE:
		$AbilityPanel/AttackTitle/Wheel.show()
		$AbilityPanel/AttackTitle/Wheel.color = ab.WheelColor
		$AbilityPanel/AttackTitle/Wheel.draw_wheel()
		$AbilityPanel/AttackTitle/Wheel.draw_wheel()
	else: $AbilityPanel/AttackTitle/Wheel.hide()
	$AbilityPanel/AttackTitle.text = ab.name
	#$AbilityPanel/AttackTitle.icon = ab.Icon
	$AbilityPanel/AttackTitle/RichTextLabel.text = Colorizer.colorize(ab.description)


func _on_complimentary() -> void:
	inactive = true
	Global.complimentary_ui(actor)


func _input(event: InputEvent) -> void:
	if not inactive and actor in Party.current:
		if event.is_action_pressed("RightTrigger"):
			var next_char: Actor
			if Party.current.size() > Party.current.find(actor) + 1:
				next_char = Party.current[Party.current.find(actor) + 1]
			else:
				next_char = Party.Leader

			if is_instance_valid(next_char):
				Global.member_details(next_char, stability_menu)
				queue_free()
		elif event.is_action_pressed("LeftTrigger"):
			var next_char := Party.current[Party.current.find(actor) - 1]

			if is_instance_valid(next_char):
				Global.member_details(next_char, stability_menu)
				queue_free()
