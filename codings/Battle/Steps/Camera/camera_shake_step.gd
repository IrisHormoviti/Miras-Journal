@tool
extends BattleStep
class_name CameraShakeStep

## How far the camera shakes.
@export var amount := 8.0
@export var repeat := 7
@export var duration := 0.5
## When false, the next step starts while the camera is still shaking.
@export var wait := false


func run(ctx: ActionSequenceContext) -> void:
	if wait:
		await ctx.battle.screen_shake(amount, repeat, duration)
	else:
		ctx.battle.screen_shake(amount, repeat, duration)


func _to_string() -> String:
	return "Shake the camera by %s" % str(amount)


func _icon() -> String:
	return "Camera"
