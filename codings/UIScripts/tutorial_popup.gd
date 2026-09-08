extends CanvasLayer
class_name TutorialPopup


func start(id: String) -> void:
	$Border2.hide()
	$Border2/Control/Next.icon = Controller.get_scheme().ConfirmIcon
	await call(id)


func pop_down() -> void:
	var t := create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property($Border1, "position", Vector2(0, 622), 0.3).from(Vector2(-200, 622))
	t.tween_property($Border1, "modulate", Color.WHITE, 0.3).from(Color.TRANSPARENT)
	await t.finished


func dash() -> void:
	%Text.text = "[center]Hold [img height=48]" + (Controller.get_scheme().Dash).resource_path + "[/img] to dash.[/center]"
	await pop_down()
	while not Input.is_action_pressed("Dash"):
		await Event.wait()

	await Event.wait(3)
	await close()
	%Text.text = "[center]Jump over obstacles by dashing through them.[/center]"
	await pop_down()
	await Event.wait(6)
	await close()
	queue_free()


func ov_attack() -> void:
	%Text.text = "[center]Press [img width=48]" + (Controller.get_scheme().OVAttack).resource_path + "[/img] to to swing the axe.[/center]"
	await pop_down()
	while not Input.is_action_pressed("OVAttack"):
		await Event.wait()

	await Event.wait(3)
	await close()
	queue_free()


func party() -> void:
	%Text.text = "[center]Press [img]" + (Controller.get_scheme().Select).resource_path + "[/img] to check on your Party.[/center]"
	await pop_down()
	await Event.wait(2)
	while not Input.is_action_pressed("MainMenu"):
		await Event.wait()
		if Global.controllable == false: break

	await close()
	queue_free()


func bag() -> void:
	%Text.text = "[center]Press [img width=48]" + (Controller.get_scheme().Menu).resource_path + "[/img] to check your bag.[/center]"
	Loader.save()
	await pop_down()
	while not Input.is_action_pressed("PartyMenu"):
		await Event.wait()
		if Global.controllable == false: break

	await close()
	queue_free()


func walk() -> void:
	if Controller.device == "Keyboard":
		%Text.text = "[center]Use the arrow keys to walk.[/center]"
	else: %Text.text = "[center]Use the left stick or D-Pad to walk.[/center]"
	await pop_down()
	await Event.wait(4)
	await close()
	queue_free()


func weapon_attack() -> void:
	await Event.wait(0.1, false)
	Global.bt.focus_cam(Party.Leader)
	$Border2.show()
	$Border2/Control/Arrow.hide()
	$Border2.position = Vector2(50, 201)
	$Border2/Control/Next.hide()
	$Border2/Text.text = "Press [img width=48]" + (Controller.get_scheme().AttackIcon).resource_path + "[/img] to use a Weapon Attack."
	await Global.bt.get_node("BattleUI").attack
	queue_free()


func ability() -> void:
	await Event.wait(0.1, false)
	Global.bt.focus_cam(Party.Leader)
	$Border2.show()
	$Border2/Control/Arrow.hide()
	$Border2.position = Vector2(50, 201)
	$Border2/Control/Next.hide()
	$Border2/Text.text = "Press [img width=48]" + (Controller.get_scheme().AbilityIcon).resource_path + "[/img] to use a Magic Ability."
	await Global.bt.get_node("BattleUI").ability
	queue_free()


func aura1() -> void:
	await Event.wait(0.5, false)
	$Border2.show()
	$Border2.position = Vector2(290, 15)
	$Border2/Text.text = Colorizer.colorize("This is the AP meter.")
	await await_next()
	$Border2/Text.text = Colorizer.colorize("It represents how much power Mira currently has.")
	await await_next()
	$Border2/Text.text = Colorizer.colorize("This meter will be drained whenever a magic Ability is used.")
	await await_next()
	Global.bt.lock_turn = false
	queue_free()


func complimentary() -> void:
	await Event.wait(1)
	Audio.confirm_sound()
	$Border2.show()
	$Border2.position = Vector2(840, 450)
	$Border2/Control/Arrow.hide()
	$Border2/Text.text = Colorizer.colorize("By spending time with other people, you can unlock [b]Complimentary Abilities[/b].")
	await await_next()
	$Border2/Text.text = Colorizer.colorize("These abilities can be used by anyone in your party! Even by multiple members at once!")
	await await_next()
	$Border2/Text.text = Colorizer.colorize("However, a new skill always needs practice...")
	await await_next()
	$Border2/Text.text = Colorizer.colorize("Complimentary Abilities may not succeed the first time used...")
	await await_next()
	$Border2/Text.text = Colorizer.colorize("...And the further they are from the user's aura color, the harder they are to learn.")
	await await_next()
	$Border2/Text.text = Colorizer.colorize("But with enough practice, anyone can master them!")
	await await_next()
	$Border2/Text.text = Colorizer.colorize("To equip one, go to the party menu, select a member, go to Abilities, then \"Set Complimentary\".")
	await await_next()
	queue_free()


func aura2() -> void:
	await Event.wait(1, false)
	Global.bt.focus_cam(Party.Leader)
	$Border2.show()
	$Border2/Control/Arrow.hide()
	$Border2.position = Vector2(612, 201)
	$Border2/Text.text = "Looks like the enemy is preparing to attack again."
	await await_next()
	$Border2/Control/Arrow.show()
	$Border2.position = Vector2(290, 15)
	$Border2/Text.text = "Mira's AP is also pretty low right now."
	await await_next()
	$Border2/Control/Arrow.hide()
	$Border2.position = Vector2(104, 279)
	$Border2/Text.text = Colorizer.colorize("Using her Aura Guard ability, Mira will take less damage, while increasing her AP when hit.").replace("guard", "Guard")
	await await_next()
	Global.bt.lock_turn = false
	queue_free()


func aura3() -> void:
	await Event.wait(1, false)
	Global.bt.focus_cam(Party.Leader)
	$Border2.show()
	$Border2/Control/Arrow.hide()
	$Border2/Control/Arrow.hide()
	$Border2.position = Vector2(104, 279)
	$Border2/Text.text = "Using weapon attacks will also give some AP."
	await await_next()
	$Border2/Text.text = "So go on and finish off this enemy!"
	await await_next()
	Global.bt.lock_turn = false
	queue_free()


func await_input(input := "DialogNext") -> void:
	while Input.is_action_pressed(input): await Event.wait()
	while not Input.is_action_pressed(input): await Event.wait()
	Audio.confirm_sound()


func await_next() -> void:
	print("boing")
	await $Border2/Control/Next.pressed
	print("boing2")
	Audio.confirm_sound()


func close() -> void:
	var t := create_tween()
	t.set_parallel()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property($Border1, "position", Vector2(-200, 622), 0.3)
	t.tween_property($Border1, "modulate", Color.TRANSPARENT, 0.3)
	await t.finished
