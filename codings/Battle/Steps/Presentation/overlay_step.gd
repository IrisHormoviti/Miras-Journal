@tool
extends BattleStep
class_name OverlayStep

enum Mode {
	CALLOUT,
	CUT_IN,
}

@export var mode: Mode = Mode.CALLOUT:
	set(value):
		mode = value
		notify_property_list_changed()
@export var ability: Ability
@export var actor: ActorRef
@export var image: StringName = &""
## When false, the next step starts while the overlay is still showing.
@export var wait := false


func run(ctx: ActionSequenceContext) -> void:
	match mode:
		Mode.CALLOUT:
			var shown := ability
			if shown == null:
				shown = ctx.ability
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
		Mode.CUT_IN:
			var subject := actor.resolve(ctx) if actor != null else ctx.caster
			var picture := str(image)
			if picture.is_empty() and subject != null:
				picture = subject.codename
			if wait:
				await ctx.battle.cut_in(picture)
			else:
				ctx.battle.cut_in(picture)


func _to_string() -> String:
	if mode == Mode.CALLOUT:
		if ability != null:
			return "Callout '%s'" % ability.name

		return "Callout"

	if not str(image).is_empty():
		return "Cut in '%s'" % image

	return "Cut in %s" % (str(actor) if actor != null else "Caster")


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode"]
	match mode:
		Mode.CALLOUT:
			visible.append_array(["ability", "wait"])
		Mode.CUT_IN:
			visible.append_array(["actor", "image", "wait"])
	StepEditor.only(property, visible)


func _icon() -> String:
	return "TextureRect"
