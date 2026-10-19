@tool
extends BattleStep
class_name WaitStep

@export var duration := 1.0
@export var process_while_paused := false
## Use a random duration between the two values instead of `duration`.
@warning_ignore("shadowed_global_identifier")
@export var randomize := false:
	set(value):
		randomize = value
		notify_property_list_changed()
@export var random_min := 0.0
@export var random_max := 1.0


func run(ctx: ActionSequenceContext) -> void:
	var seconds := randf_range(random_min, random_max) if randomize else duration
	if seconds <= 0:
		return

	await ctx.battle.get_tree().create_timer(seconds, process_while_paused).timeout


func _to_string() -> String:
	if randomize:
		return "Wait %.2f-%.2f s" % [random_min, random_max]

	return "Wait %.2f s" % duration


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["process_while_paused", "randomize"]
	if randomize:
		visible.append_array(["random_min", "random_max"])
	else:
		visible.append("duration")
	StepEditor.only(property, visible)


func _icon() -> String:
	return "Timer"
