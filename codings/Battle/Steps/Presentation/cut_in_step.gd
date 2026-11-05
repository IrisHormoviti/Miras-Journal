@tool
extends BattleStep
class_name CutInStep

## Slides in a character's cut-in picture.

@export var actor: ActorRef
@export var image: StringName = &""
## When false, the next step starts while the cut-in is still showing.
@export var wait := false


func run(ctx: ActionSequenceContext) -> void:
	var subject := actor.resolve(ctx) if actor != null else ctx.caster
	var picture := str(image)

	if picture.is_empty() and subject != null:
		picture = subject.codename

	if wait:
		await ctx.battle.cut_in(picture)
	else:
		ctx.battle.cut_in(picture)


func _to_string() -> String:
	if not str(image).is_empty():
		return "Cut in '%s'" % image

	return "Cut in %s" % (str(actor) if actor != null else "Caster")


func _validate_property(property: Dictionary) -> void:
	StepEditor.only(property, ["actor", "image", "wait"])


func _icon() -> String:
	return "TextureRect"
