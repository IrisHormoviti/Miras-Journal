@tool
extends BattleStep
class_name WaitStep

@export var duration := 1.0
## Use a random duration between the two values instead of `duration`.
@export var random_duration := false:
	set(value):
		random_duration = value
		notify_property_list_changed()
@export var random_min := 0.0
@export var random_max := 1.0
@export_group("Parameters")
@export var process_while_paused := false


func run(ctx: ActionSequenceContext) -> void:
	var seconds := randf_range(random_min, random_max) if random_duration else duration

	if seconds <= 0:
		return

	await ctx.battle.get_tree().create_timer(seconds, process_while_paused).timeout


func _to_string() -> String:
	if random_duration:
		return "Wait %ss - %ss" % [str(random_min), str(random_max)]

	return "Wait %ss" % str(duration)


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["process_while_paused", "random_duration"]

	if random_duration:
		visible.append_array(["random_min", "random_max"])
	else:
		visible.append("duration")

	StepEditor.only(property, visible)


func _icon() -> String:
	return "Timer"
