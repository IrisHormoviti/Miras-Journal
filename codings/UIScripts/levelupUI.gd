extends Control

var index: int = 0
signal closed
var working_chara: Actor
var learnable: Ability
var active := false


func _ready() -> void:
	$ChooseUpgrade/Continue.hide()
	$ChooseUpgrade/Cursor/Cont/Button.hide()
	hide()


func got_complimentary(ability: Ability, from_name: String) -> void:
	var color1 := ability.WheelColor
	var color2 := ability.WheelColor
	var color3 := ability.WheelColor
	color2.v -= 0.2
	color3.v -= 0.5
	learnable = ability
	$ChooseUpgrade/NewAb/Hbox/Text.text = ability.name
	$ChooseUpgrade/NewAb/Hbox/Icon.texture = ability.Icon
	$Line1.position = Vector2(0, 243)
	$Line1.rotation_degrees = 0
	$GotComplimentaryText.position = Vector2(-52, 364)
	$Line1.color = color1
	$Line1/Line3.color = color1
	$Line1/Line2.color = color2
	$Line1/Line3/Line2.color = color2
	$Line1/Line2/Line3.color = color3
	$Line1/Line3/Line2/Line3.color = color3
	$Line1/Bg.size.y = 10
	$GotComplimentaryText.add_theme_color_override("default_color", color1)
	$ChooseUpgrade.modulate = Color.TRANSPARENT
	$ChooseUpgrade.position.y = 500
	$ChooseUpgrade/Label.hide()
	$ChooseUpgrade/Desc.modulate = Color.TRANSPARENT
	$ChooseUpgrade/HPCont.hide()
	$ChooseUpgrade/APCont.hide()
	$ChooseUpgrade/Cursor.hide()
	$ChooseUpgrade/NewAb.hide()
	$ChooseUpgrade/NewAb.modulate = Color(1,1,1,0)
	$ChooseUpgrade/Actor.hide()
	$ChooseUpgrade/NewAb.position = Vector2(430, 430)

	complimentary_cutin(from_name, color3)
	await Event.wait(2, false)

	var t := create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_QUINT)
	t.tween_property($Line1, "position", Vector2(-32, -100), 0.5)
	t.tween_property($Line1, "rotation_degrees", -6.2, 0.5)
	t.tween_property($GotComplimentaryText, "position", Vector2(-180, 11), 0.5)
	t.tween_property($Line1/Bg, "size:y", 800, 0.5)
	t.tween_property($ChooseUpgrade, "modulate", Color.WHITE, 0.5)
	t.tween_property($ChooseUpgrade, "position:y", 0, 0.5)

	await t.finished
	$ChooseUpgrade/NewAb/Hbox/Icon.texture = ability.Icon
	$ChooseUpgrade/NewAb/Hbox/Text.text = ability.name
	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	#t.tween_property($ChooseUpgrade/NewAb, "self_modulate", Color.WHITE, 1).from(Color(10, 10, 10, 1))
	$ChooseUpgrade/NewAb.show()
	t.tween_property($ChooseUpgrade/NewAb, "modulate", Color.WHITE, 1).from(Color(1,1,1, 0))
	t.tween_property($ChooseUpgrade/NewAb, "scale", Vector2(1.5, 1.5), 1).from(Vector2(2, 2))

	await Event.wait(1, false)
	$ChooseUpgrade/Desc.show()
	$ChooseUpgrade/Desc.text = Colorizer.colorize(ability.description)
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.set_parallel()
	t.tween_property($ChooseUpgrade/NewAb, "position:y", 313, 0.5)
	t.tween_property($ChooseUpgrade/Desc, "modulate", Color.WHITE, 0.5)

	$Glow.modulate = color1
	t.tween_property($Glow, "modulate:a", 1, 3).from(0)

	await Event.wait(1, false)

	if Global.complimentaries.is_empty():
		await Event.pop_tutorial("complimentary")

	$ChooseUpgrade/Continue.icon = Controller.get_scheme().ConfirmIcon
	$ChooseUpgrade/Continue.show()


func levelup(chara: Actor) -> void:
	working_chara = chara
	find_learnable()
	$ChooseUpgrade/Continue.hide()
	$ChooseUpgrade/Cursor.show()
	index = 0
	$ChooseUpgrade/Actor.sprite_frames = await chara.get_BT()
	$ChooseUpgrade/HPCont.position.y = 374
	$ChooseUpgrade/APCont.position.y = 515
	$ChooseUpgrade/NewAb.position.y = 654
	$ChooseUpgrade/NewAb/Hbox/Text.text = "New Ability"
	$ChooseUpgrade/NewAb/Hbox/Icon.texture = await Loader.load_res("res://UI/LevelUp/QuestionMark.png")
	$Line1.position = Vector2(0, 243)
	$Line1.rotation_degrees = 0
	$LevelupText.position = Vector2(-52, 364)
	$Line1.color = chara.CharacterBoxProfile.Bord1
	$Line1/Line3.color = chara.CharacterBoxProfile.Bord1
	$Line1/Line2.color = chara.CharacterBoxProfile.Bord2
	$Line1/Line3/Line2.color = chara.CharacterBoxProfile.Bord2
	$Line1/Line2/Line3.color = chara.CharacterBoxProfile.Bord3
	$Line1/Line3/Line2/Line3.color = chara.CharacterBoxProfile.Bord3
	$Line1/Bg.size.y = 10
	$LevelupText.add_theme_color_override("default_color", chara.CharacterBoxProfile.Bord1)
	$ChooseUpgrade.modulate = Color.TRANSPARENT
	$ChooseUpgrade.position.y = 500
	$ChooseUpgrade/HPCont.modulate = Color.TRANSPARENT
	$ChooseUpgrade/APCont.modulate = Color.TRANSPARENT
	$ChooseUpgrade/NewAb.modulate = Color.TRANSPARENT
	$ChooseUpgrade/HPCont/HPBox/HPText.text = str(chara.MaxHP)
	$ChooseUpgrade/APCont/APBox/APText.text = str(chara.MaxAura)
	$ChooseUpgrade/Cursor.modulate = Color.TRANSPARENT
	var hbox: StyleBoxFlat = $ChooseUpgrade/HPCont/HPBox/Health.get_theme_stylebox("fill")
	hbox.bg_color = chara.MainColor
	$ChooseUpgrade/HPCont/HPBox/Health.add_theme_stylebox_override("fill", hbox.duplicate())
	var abox: StyleBoxFlat = $ChooseUpgrade/APCont/APBox/Aura.get_theme_stylebox("fill")
	abox.bg_color = chara.SecondaryColor
	$ChooseUpgrade/APCont/APBox/Aura.add_theme_stylebox_override("fill", abox.duplicate())
	$ChooseUpgrade/HPCont/HPBox/Health.value = chara.MaxHP
	$ChooseUpgrade/APCont/APBox/Aura.value = chara.MaxAura
	$ChooseUpgrade/Desc.modulate = Color.TRANSPARENT
	level_cutin(chara)
	await Event.wait(2, false)
	var t := create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_QUINT)
	t.tween_property($Line1, "position", Vector2(-32, -100), 0.5)
	t.tween_property($Line1, "rotation_degrees", -6.2, 0.5)
	t.tween_property($LevelupText, "position", Vector2(-240, 11), 0.5)
	t.tween_property($Line1/Bg, "size:y", 800, 0.5)
	t.tween_property($ChooseUpgrade, "modulate", Color.WHITE, 0.5)
	t.tween_property($ChooseUpgrade, "position:y", 0, 0.5)
	t.tween_property($ChooseUpgrade/Label, "modulate", Color.WHITE, 0.3)
	$ChooseUpgrade/Actor.play("Idle")
	await Event.wait(0.8, false)
	t = create_tween()
	t.set_parallel()
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property($ChooseUpgrade/HPCont, "position:x", 160, 0.2).from(-100)
	t.tween_property($ChooseUpgrade/HPCont, "modulate", Color.WHITE, 0.2)
	await Event.wait(0.8, false)
	t = create_tween()
	t.set_parallel()
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property($ChooseUpgrade/APCont, "position:x", 160, 0.2).from(-100)
	t.tween_property($ChooseUpgrade/APCont, "modulate", Color.WHITE, 0.2)
	await Event.wait(0.8, false)
	if learnable != null:
		t = create_tween()
		t.set_parallel()
		t.set_trans(Tween.TRANS_BACK)
		t.tween_property($ChooseUpgrade/NewAb, "position:x", 160, 0.2).from(-100)
		t.tween_property($ChooseUpgrade/NewAb, "modulate", Color.WHITE, 0.2)
		await Event.wait(0.8, false)

	$ChooseUpgrade/Cursor/Cont/Button.show()
	$ChooseUpgrade/Cursor/Cont/Button.icon = Controller.get_scheme().ConfirmIcon
	t = create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.tween_property($ChooseUpgrade/Cursor/Cont,
		"size:x", 190, 0.3).from(1)

	t.tween_property($ChooseUpgrade/Cursor, "modulate", Color.WHITE, 0.2)
	index = 0
	active = true


func level_cutin(chara: Actor) -> void:
	$LevelupText.show()
	$GotComplimentaryText.hide()
	Hud.hide_all()
	scale.y = 0.1

	for i in $Line1/NameChain.get_children():
		i.text = (chara.FirstName + " " + chara.LastName + " ").to_upper()
		i.add_theme_color_override("font_color", chara.CharacterBoxProfile.Bord3)

	for i in $Line1/NameChain2.get_children():
		i.text = (chara.FirstName + " " + chara.LastName + " ").to_upper()
		i.add_theme_color_override("font_color", chara.CharacterBoxProfile.Bord3)

	var t := create_tween()
	show()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "scale:y", 1, 0.3)
	t.tween_property($Line1/NameChain, "position:x", -800, 10).from(0)
	t.tween_property($Line1/NameChain2, "position:x", 2300, 10).from(1400)


func complimentary_cutin(from_name: String, font_color: Color) -> void:
	$LevelupText.hide()
	$GotComplimentaryText.show()
	Hud.hide_all()
	scale.y = 0.1
	from_name += " "

	for i in $Line1/NameChain.get_children():
		i.text = (from_name).to_upper()
		i.add_theme_color_override("font_color", font_color)

	for i in $Line1/NameChain2.get_children():
		i.text = (from_name).to_upper()
		i.add_theme_color_override("font_color", font_color)

	var t := create_tween()
	show()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "scale:y", 1, 0.3)
	t.tween_property($Line1/NameChain, "position:x", -800, 10).from(0)
	t.tween_property($Line1/NameChain2, "position:x", 2300, 10).from(1400)


func _input(event: InputEvent) -> void:
	if not active: return
	if Input.is_action_just_pressed("ui_down"):
		index += 1

		if index == 3: index = 0
		move_menu()

	if Input.is_action_just_pressed("ui_up"):
		index -= 1

		if index == -1: index = 2
		move_menu()


func move_menu() -> void:
	Audio.cursor_sound()
	var ypos: int
	match index:
		0:
			ypos = 375
			$ChooseUpgrade/Cursor/Cont/Button.text = "Upgrade Health"

		1:
			ypos = 515
			$ChooseUpgrade/Cursor/Cont/Button.text = "Upgrade Aura"

		2:
			if learnable != null:
				ypos = 646
				$ChooseUpgrade/Cursor/Cont/Button.text = "Learn Ability"
			else:
				index = 0
				move_menu()
				return

	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.tween_property($ChooseUpgrade/Cursor, "position:y", ypos, 0.1)


func find_learnable() -> void:
	learnable = working_chara.find_learnable()

var count: int


func _confirm() -> void:
	if not active: return
	active = false
	$ChooseUpgrade/Cursor.hide()
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUINT)
	t.set_parallel()
	Audio.confirm_sound()
	t.tween_property($ChooseUpgrade/Label, "modulate", Color.TRANSPARENT, 0.3)
	match index:
		0:
			t.tween_property($ChooseUpgrade/HPCont, "position", Vector2(334, 450), 0.6)
			t.tween_property($ChooseUpgrade/APCont, "position:x", 400, 0.3)
			t.tween_property($ChooseUpgrade/APCont, "modulate", Color.TRANSPARENT, 0.3)
			t.tween_property($ChooseUpgrade/NewAb, "position:x", 400, 0.3)
			t.tween_property($ChooseUpgrade/NewAb, "modulate", Color.TRANSPARENT, 0.3)
			await t.finished
			working_chara.MaxHP += working_chara.HpOnSLvUp
			working_chara.Health = working_chara.MaxHP
			t = create_tween()
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_SINE)
			t.set_parallel()
			count = $ChooseUpgrade/HPCont/HPBox/Health.value
			t.tween_property(self, "count", working_chara.MaxHP, 1)
			t.tween_property($ChooseUpgrade/HPCont/HPBox/Health, "value", working_chara.MaxHP, 1)
			while $ChooseUpgrade/HPCont/HPBox/HPText.text != str(working_chara.MaxHP):
				$ChooseUpgrade/HPCont/HPBox/HPText.text = str(count)
				await Event.wait()

		1:
			t.tween_property($ChooseUpgrade/APCont, "position", Vector2(334, 450), 0.6)
			t.tween_property($ChooseUpgrade/HPCont, "position:x", 400, 0.3)
			t.tween_property($ChooseUpgrade/HPCont, "modulate", Color.TRANSPARENT, 0.3)
			t.tween_property($ChooseUpgrade/NewAb, "position:x", 400, 0.3)
			t.tween_property($ChooseUpgrade/NewAb, "modulate", Color.TRANSPARENT, 0.3)
			await t.finished
			working_chara.MaxAura += working_chara.ApOnSLvUP
			working_chara.Aura = working_chara.MaxAura
			t = create_tween()
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_SINE)
			t.set_parallel()
			count = $ChooseUpgrade/APCont/APBox/Aura.value
			t.tween_property(self, "count", working_chara.MaxAura, 1)
			t.tween_property($ChooseUpgrade/APCont/APBox/Aura, "value", working_chara.MaxAura, 1)
			while $ChooseUpgrade/APCont/APBox/APText.text != str(working_chara.MaxAura):
				$ChooseUpgrade/APCont/APBox/APText.text = str(count)
				await Event.wait()

		2:
			t.tween_property($ChooseUpgrade/NewAb, "position", Vector2(334, 450), 0.6)
			t.tween_property($ChooseUpgrade/HPCont, "position:x", 400, 0.3)
			t.tween_property($ChooseUpgrade/HPCont, "modulate", Color.TRANSPARENT, 0.3)
			t.tween_property($ChooseUpgrade/APCont, "position:x", 400, 0.3)
			t.tween_property($ChooseUpgrade/APCont, "modulate", Color.TRANSPARENT, 0.3)
			await t.finished
			t = create_tween()
			t.set_ease(Tween.EASE_IN)
			t.set_trans(Tween.TRANS_QUART)
			t.set_parallel()
			t.tween_property($ChooseUpgrade/NewAb, "self_modulate", Color(10, 10, 10, 1), 1.5)
			t.tween_property($ChooseUpgrade/NewAb/Hbox, "modulate", Color.TRANSPARENT, 1.5)
			t.tween_property($ChooseUpgrade/NewAb, "scale", Vector2(1.8, 1.8), 1.5)
			await t.finished
			working_chara.Abilities.append(learnable)
			$ChooseUpgrade/NewAb/Hbox/Icon.texture = learnable.Icon
			$ChooseUpgrade/NewAb/Hbox/Text.text = learnable.name
			t = create_tween()
			t.set_parallel()
			t.tween_property($ChooseUpgrade/NewAb, "self_modulate", Color.WHITE, 0.1)
			t.tween_property($ChooseUpgrade/NewAb/Hbox, "modulate", Color.WHITE, 0.1)
			t.tween_property($ChooseUpgrade/NewAb, "scale", Vector2(1.5, 1.5), 0.1)
			await Event.wait(1, false)
			$ChooseUpgrade/Desc.text = Colorizer.colorize(learnable.description)
			t = create_tween()
			t.set_ease(Tween.EASE_OUT)
			t.set_trans(Tween.TRANS_QUART)
			t.set_parallel()
			t.tween_property($ChooseUpgrade/NewAb, "position:y", 313, 0.5)
			t.tween_property($ChooseUpgrade/Desc, "modulate", Color.WHITE, 0.5)
			await t.finished

	$ChooseUpgrade/Continue.icon = Controller.get_scheme().ConfirmIcon
	$ChooseUpgrade/Continue.show()


func close() -> void:
	Audio.confirm_sound()
	var t := create_tween()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_QUINT)
	t.tween_property(self, "scale:y", 0, 0.3)
	await t.finished
	closed.emit()
	t.kill()
	$"..".queue_free()
