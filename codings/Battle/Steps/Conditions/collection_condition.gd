@tool
extends BattleCondition
class_name CollectionCondition

## Checks whether one of an actor's collections is empty or populated. The
## states and summoned-ally checks share this condition.

enum Collection {
	STATES,
	SUMMONED_ALLIES,
}

const COLLECTION_LABELS := "States,Summoned allies"

@export_group("Subject")
## Who to check. Defaults to the branch target.
@export var actor: ActorRef
@export_group("Collection")
## Which collection to check.
@export var collection: Collection = Collection.STATES
## Check whether the collection is empty (on) or populated (off).
@export var empty := true


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)

	if str(property.name) == "collection":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = COLLECTION_LABELS


func check(ctx: ActionSequenceContext) -> bool:
	var target := subject(ctx, actor)

	if target == null:
		return false

	var items: Array = (
		Array(target.states)
		if collection == Collection.STATES
		else Array((target as Enemy).summoned_allies if target is Enemy else [])
	)

	return items.is_empty() == empty


func _to_string() -> String:
	var what := "states" if collection == Collection.STATES else "summoned allies"

	return "%s %s %s" % [
		ref_label(actor),
		"has no" if empty else "has",
		what,
	]


func _icon() -> String:
	return "CheckBox" if collection == Collection.STATES else "SkeletonPreview"
