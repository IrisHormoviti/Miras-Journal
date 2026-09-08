extends CanvasLayer
@onready var Troop: Array[Actor] = get_parent().Troop
@onready var CurEnemy: Actor
@onready var Bt: Battle = $".."
var t: Tween
var lock := false


func _ready() -> void:
	$AllEnemies.show()
	$EnemyFocus.hide()
	$AllEnemies.position.x = 1300


func all_enemy_ui(from := false) -> void:
	lock = false
	Troop = get_parent().Troop
	$AllEnemies.show()
	if from:
		$AllEnemies.position.x = 1300

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUART)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property($AllEnemies, "position:x", 1081, 0.2)
	for enemy in Troop:
		if is_instance_valid(enemy):
			find_box(enemy)

	$EnemyFocus.hide()
	$AllEnemies.move_child($AllEnemies/OtherEnemies, -1)
	for panel in $AllEnemies.get_children():
		if panel.has_meta("enemy") and is_instance_valid(panel.get_meta("enemy")):
			panel.show()
		elif panel.name != "OtherEnemies": panel.hide()

	for panel in $AllEnemies/OtherEnemies/Margin/VBox.get_children():
		if (panel.has_meta("enemy") and
		is_instance_valid(panel.get_meta("enemy")) and
		panel.get_meta("enemy").Health > 0):
			panel.show()
		else:
			panel.hide()

	if Troop.size() != 0:
		CurEnemy = Troop[0]
		make_box(Troop[0], $EnemyFocus)
		_check_party()


func _on_battle_ui_target_foc(cur: Actor) -> void:
	CurEnemy = cur
	_check_party()
	$AllEnemies.hide()
	make_box(cur, $EnemyFocus)
	$EnemyFocus.show()
	$EnemyFocus/Name.text = cur.FirstName
	$EnemyFocus/Health.value = cur.Health
	$EnemyFocus/Health.max_value = cur.MaxHP
	$EnemyFocus/Aura.value = cur.Aura
	$EnemyFocus/Aura.max_value = cur.MaxAura
	$EnemyFocus/Health/HpText.add_theme_color_override("font_outline_color", CurEnemy.MainColor)
	$EnemyFocus/Health/HpText.text = str(CurEnemy.Health)


func find_box(enemy: Actor) -> Control:
	if enemy.HealthBar:
		for i in $AllEnemies.get_children():
			if i.has_meta("enemy") and i.get_meta("enemy") == enemy:
				return i

		#Didn't find one, make one instead
		var panel: Panel = $AllEnemies/Temp.duplicate()
		panel.name = "Enemy" + str(Troop.find(enemy))
		$AllEnemies.add_child(panel)
		make_box(enemy, panel)
		return panel
	else:
		for i in $AllEnemies/OtherEnemies/Margin/VBox.get_children():
			if i.has_meta("enemy") and i.get_meta("enemy") == enemy:
				return i

			#Didn't find one, make one instead

		var panel: Control = $AllEnemies/OtherEnemies/Margin/VBox/Temp.duplicate()
		panel.name = "Enemy" + str(Troop.find(enemy))
		$AllEnemies/OtherEnemies/Margin/VBox.add_child(panel)
		make_box(enemy, panel)
		return panel


func _check_party() -> void:
	Hud._check_party()
	Troop = get_parent().Troop

	if t: t.stop()
	for i in Troop:
		check_panel(i, find_box(i))

	check_panel(CurEnemy, $EnemyFocus)
	$EnemyFocus/Name.text = CurEnemy.FirstName

	for i in $EnemyFocus/States.get_children():
		if i.name != "State": i.queue_free()

	for i in CurEnemy.States:
		var dub: Control = $EnemyFocus/States/State.duplicate()
		dub.texture = i.icon
		dub.show()
		dub.tooltip_text = i.name + "\n" + i.Description
		dub.name = i.name
		$EnemyFocus/States.add_child(dub)

	$EnemyFocus/Health.max_value = CurEnemy.MaxHP
	$EnemyFocus/Aura.max_value = CurEnemy.MaxAura
	$EnemyFocus/Health/HpText.text = str(CurEnemy.Health)

	if CurEnemy != get_parent().CurrentChar and lock == false and get_parent().Action:
		lock = true

		if is_instance_valid(t): t.kill()
		t = create_tween()
		t.set_parallel(true)
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property($EnemyFocus/Health, "value", CurEnemy.Health, 0.3)
		if CurEnemy.Health == 0: t.tween_property($EnemyFocus/Aura, "value", 0, 0.4)
		else: t.tween_property($EnemyFocus/Aura, "value", CurEnemy.Aura, 0.3)
		await t.finished
		lock = false
	elif not lock:
		$EnemyFocus/Health.value = CurEnemy.Health
		$EnemyFocus/Aura.value = CurEnemy.Aura

	$EnemyFocus/Icon.texture = CurEnemy.PartyIcon
	#if Troop.size() != 0:
		#make_box(Troop[0], $AllEnemies/Enemy0)


func check_panel(chara: Actor, panel: Control) -> void:
	if panel == null: return
	if chara.FirstName.length() > 16: panel.get_node("Name").add_theme_font_size_override("font_size", 12)
	elif chara.FirstName.length() > 12: panel.get_node("Name").add_theme_font_size_override("font_size", 14)
	elif chara.FirstName.length() > 6: panel.get_node("Name").add_theme_font_size_override("font_size", 18)
	else: panel.get_node("Name").add_theme_font_size_override("font_size", 20)
	panel.get_node("Name").text = chara.FirstName
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(panel.get_node("Health"), "value", chara.Health, 0.3)
	panel.get_node("Health").max_value = chara.MaxHP

	if panel.get_node_or_null("Aura"):
		t.tween_property(panel.get_node("Aura"), "value", chara.Aura, 0.3)
		panel.get_node("Aura").max_value = chara.MaxAura

	color_box(chara, panel)


func _on_battle_ui_ability() -> void:
	if Bt.ui.get_node("DescPaper/ShowWheel/Wheel").visible:
		colapse_root()

	$EnemyFocus.hide()


func colapse_root() -> void:
	t = create_tween()
	t.tween_property($AllEnemies, "position:x", 1300, 0.1)


#func _process(delta):
#	if get_parent().Action:
#		_check_party()

#	pass


func make_box(en: Actor, node: Control) -> void:
	#node.show()
	node.set_meta("enemy", en)
	node.get_node("Icon").texture = en.PartyIcon
	#node.get_node("Icon").modulate = en.MainColor*2
	color_box(en, node)


func color_box(en: Actor, node: Control) -> void:
	var hbox: StyleBoxFlat = node.get_node("Health").get_theme_stylebox("fill")
	hbox.bg_color = en.MainColor
	node.get_node("Health").add_theme_stylebox_override("fill", hbox.duplicate())
	if node.get_node_or_null("Aura"):
		var abox: StyleBoxFlat = node.get_node("Aura").get_theme_stylebox("fill")

		if en.SecondaryColor == Color.BLACK:
			en.SecondaryColor = en.MainColor
			en.SecondaryColor.h += 0.83

		abox.bg_color = en.SecondaryColor
		node.get_node("Aura").add_theme_stylebox_override("fill", abox.duplicate())

	if node.has_node("Border1"):
		var bord1: StyleBoxFlat = node.get_node("Border1").get_theme_stylebox("panel")
		bord1.border_color = en.MainColor
		node.get_node("Border1").add_theme_stylebox_override("panel", bord1.duplicate())
		var bord2: StyleBoxFlat = node.get_node("Border1/Border2").get_theme_stylebox("panel")
		bord2.border_color = Color.from_hsv(en.MainColor.h, en.MainColor.s - 0.2, max(0.3, en.MainColor.v - 0.5), 1)
		node.get_node("Border1/Border2").add_theme_stylebox_override("panel", bord2.duplicate())
		var bord3: StyleBoxFlat = node.get_node("Border1/Border2/Border3").get_theme_stylebox("panel")
		bord3.border_color = Color.from_hsv(en.MainColor.h, en.MainColor.s - 0.3, max(0.2, en.MainColor.v - 0.7), 1)
		node.get_node("Border1/Border2/Border3").add_theme_stylebox_override("panel", bord3.duplicate())
