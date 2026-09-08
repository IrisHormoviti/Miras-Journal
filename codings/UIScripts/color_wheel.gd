extends Control
class_name Wheel
@export var color: Color
var affinity: Affinity
var tar_aff: Affinity
var relation_ico: TextureRect = null
var t: Tween


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("DebugC"):
		draw_wheel()


func draw_wheel() -> void:
	if color.s != 0:
		affinity = Query.get_affinity(color)
		$Rangenear1.rotation_degrees = affinity.near_range[0]
		$Rangenear2.rotation_degrees = affinity.near_range[-1]
		#print(affinity.oposing_range.size())
		if affinity.oposing_range.size() > 15:
			$Rangeopose1.rotation_degrees = affinity.weak_range[-1]
			$Rangeopose2.show()
			$DoubleWeakIcon.show()
			$DoubleWeakIcon.rotation_degrees = affinity.oposing_hue
			$Rangeopose2.rotation_degrees = affinity.resist_range[0]
			$ResistIcon.rotation_degrees = avrage_dg($Rangeresist.rotation_degrees, $Rangeopose2.rotation_degrees)
		else:
			$Rangeopose2.hide()
			$DoubleWeakIcon.hide()
			$Rangeopose1.rotation_degrees = affinity.oposing_range[-1]
			$ResistIcon.rotation_degrees = avrage_dg($Rangeresist.rotation_degrees, $Rangeopose1.rotation_degrees)

		$Rangeweak.rotation_degrees = affinity.weak_range[0]
		#$Rangeweak2.rotation_degrees = affinity.weak_range[-1]
		#$Rangeresist1.rotation_degrees = affinity.resist_range[0]
		$Rangeresist.rotation_degrees = affinity.resist_range[-1]
		$WeakIcon.rotation_degrees = avrage_dg($Rangeopose1.rotation_degrees, $Rangeweak.rotation_degrees)
		$NearIcon.rotation_degrees = avrage_dg($Rangenear2.rotation_degrees, $Rangenear1.rotation_degrees)
		$NeturalIcon1.rotation_degrees = avrage_dg($Rangeweak.rotation_degrees, $Rangenear2.rotation_degrees)
		$NeturalIcon2.rotation_degrees = avrage_dg($Rangenear1.rotation_degrees, $Rangeresist.rotation_degrees)
		#$ColorIndicator.rotation_degrees = affinity.hue
		#var IndicatorPanel: StyleBoxFlat = $ColorIndicator.get_theme_stylebox("panel")
		#IndicatorPanel.bg_color = color


func avrage_dg(d1: float, d2: float) -> float:
	if d1 < d2: return((359 + d1) + d2) / 2
	else: return(d1 + d2) / 2


func show_atk_color(clr: Color) -> void:
	color = clr
	$ColorIndicator.hide()
	draw_wheel()
	draw_wheel.call_deferred()


func show_trg_color(clr: Color) -> void:
	if affinity == null: return
	t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	tar_aff = Query.get_affinity(clr)
	t.tween_property($ColorIndicator, "rotation_degrees", tar_aff.hue, 0.3)
	var IndicatorPanel: StyleBoxFlat = $ColorIndicator.get_theme_stylebox("panel").duplicate()
	IndicatorPanel.bg_color = tar_aff.color
	$ColorIndicator.add_theme_stylebox_override("panel", IndicatorPanel)
	$ColorIndicator.show()
	relation_ico = null
	await t.finished
	IndicatorPanel.bg_color = tar_aff.color

	if tar_aff.hue in affinity.oposing_range: relation_ico = $DoubleWeakIcon
	elif tar_aff.hue in affinity.weak_range: relation_ico = $WeakIcon
	elif tar_aff.hue in affinity.resist_range: relation_ico = $ResistIcon
	elif tar_aff.hue in affinity.near_range: relation_ico = $NearIcon

	if Global.bt.ui.stage != "target": await Event.wait(0.3)
	if relation_ico != null:
		blink_icon(relation_ico)


func blink_icon(icon: TextureRect) -> void:
	while icon == relation_ico and Global.bt.get_node("BattleUI").stage == "target":
		t = create_tween()
		t.set_ease(Tween.EASE_IN_OUT)
		t.set_trans(Tween.TRANS_SINE)
		t.tween_property(relation_ico, "modulate", Color(1, 1, 1, 0.4), 0.3).from(Color(1, 1, 1, 1))
		t.tween_property(relation_ico, "modulate", Color(1, 1, 1, 1), 0.3).from(Color(1, 1, 1, 0.4))
		await t.finished
