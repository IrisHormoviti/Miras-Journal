@tool
extends BattleStep
class_name CameraShakeStep

## How far the camera shakes.
@export var amount: float = 15
@export var duration: float = 0.5
@export var frequency: float = 0.2
## When false, the next step starts while the camera is still shaking.
@export var wait := false


func run(ctx: ActionSequenceContext) -> void:
	if wait:
		await ctx.battle.screen_shake(amount, duration, frequency)
	else:
		ctx.battle.screen_shake(amount, duration, frequency)


func _to_string() -> String:
	return "Shake the camera by %s" % str(amount)


func _icon() -> String:
	return "Camera"
