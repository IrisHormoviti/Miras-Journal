@tool
extends BattleStep
class_name ScreenStep

enum Mode {
	BATTLE_BARS,
	FADE,
}

enum FadeMode {
	IN,
	OUT,
	IN_OUT,
}

@export var mode: Mode = Mode.BATTLE_BARS:
	set(value):
		mode = value
		notify_property_list_changed()
@export var count := 0
@export var duration := 0.5
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT
@export var fade_mode: FadeMode = FadeMode.IN:
	set(value):
		fade_mode = value
		notify_property_list_changed()
@export var color := Color.BLACK
@export var in_time := 0.3
@export var out_time := 0.3
@export var wait_time := 0.0
@export var wait := true


func run(_ctx: ActionSequenceContext) -> void:
	match mode:
		Mode.BATTLE_BARS:
			if wait:
				await Loader.battle_bars(count, duration, easing)
			else:
				Loader.battle_bars(count, duration, easing)
		Mode.FADE:
			match fade_mode:
				FadeMode.IN:
					if wait:
						await Transition.fade_in(color, in_time)
					else:
						Transition.fade_in(color, in_time)
				FadeMode.OUT:
					if wait:
						await Transition.fade_out(out_time)
					else:
						Transition.fade_out(out_time)
				FadeMode.IN_OUT:
					if wait:
						await Transition.fade_in_out(color, in_time, out_time, wait_time)
					else:
						Transition.fade_in_out(color, in_time, out_time, wait_time)


func _to_string() -> String:
	if mode == Mode.FADE:
		return "Fade %s" % str(FadeMode.find_key(fade_mode)).to_lower().replace("_", " ")

	return "Battle bars with count %d" % count


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]
	match mode:
		Mode.BATTLE_BARS:
			visible.append_array(["count", "duration", "easing", "wait"])
		Mode.FADE:
			visible.append_array(["fade_mode", "wait"])
			match fade_mode:
				FadeMode.IN:
					visible.append_array(["color", "in_time"])
				FadeMode.OUT:
					visible.append("out_time")
				FadeMode.IN_OUT:
					visible.append_array(["color", "in_time", "out_time", "wait_time"])
	StepEditor.only(property, visible)


func _icon() -> String:
	return "SubViewport"
