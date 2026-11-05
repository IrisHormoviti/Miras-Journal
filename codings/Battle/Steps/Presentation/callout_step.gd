@tool
extends BattleStep
class_name CalloutStep

## Shows an ability's name callout.

@export var ability: Ability
## When false, the next step starts while the callout is still showing.
@export var wait := false


func run(ctx: ActionSequenceContext) -> void:
	var shown := ability if ability != null else ctx.ability

	if wait:
		if shown != null:
			await ctx.battle.callout(shown)
		else:
			await ctx.battle.callout()
	else:
		if shown != null:
			ctx.battle.callout(shown)
		else:
			ctx.battle.callout()


func _to_string() -> String:
	if ability != null:
		return "Callout '%s'" % ability.name

	return "Callout"


func _validate_property(property: Dictionary) -> void:
	StepEditor.only(property, ["ability", "wait"])


func _icon() -> String:
	return "TextureRect"
