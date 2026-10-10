extends Resource
class_name TrapCondition

## Decides whether an incoming hit is allowed to spring a Trap.

## Which kind of hit can spring the trap.
enum HitKind {
	ANY, ## Weapon or magic
	WEAPON, ## Only attacks that use weapon damage
	MAGIC, ## Only magic based attacks
	PHYSICAL_CONTACT ## Only attacks that make physical contact
}

## Restrict the trap to a specific kind of attack.
@export var hit_kind: HitKind = HitKind.ANY

## Color relations that spring the trap. Empty means "any"
@export var relations: Array[Wheel.Relation] = []

## Ability damage classes that spring the trap. Empty means "any".
@export var damage_types: Array[Ability.D] = []

## Ability categories (Ability.TP) that spring the trap. Empty means "any".
@export var ability_types: Array[Ability.TP] = []

## If true, only hits that actually dealt damage can spring the trap.
@export var requires_damage := true

## Minimum damage dealt for the trap to spring
@export var min_damage := 0


## Returns true if a hit matches this condition.
## `is_magic` is true for magic attacks, `relation` is the color relation,
## `damage` is the amount dealt and `ability` is the
## offending ability (may be null).
func matches(is_magic: bool, relation: Wheel.Relation, damage: int, ability: Ability) -> bool:
	if requires_damage and damage <= 0:
		return false

	if damage < min_damage:
		return false

	match hit_kind:
		HitKind.WEAPON:
			if is_magic: return false

		HitKind.MAGIC:
			if not is_magic: return false

		HitKind.PHYSICAL_CONTACT:
			if not ability.MakesPhysicalContact: return false

	if not relations.is_empty() and relation not in relations:
		return false

	if ability == null:
		# Can't filter on the ability if we don't have one
		return damage_types.is_empty() and ability_types.is_empty()

	if not damage_types.is_empty() and ability.Damage not in damage_types:
		return false

	if not ability_types.is_empty():
		var matched := false

		for t: Ability.TP in ability.Types:
			if t in ability_types:
				matched = true
				break

		if not matched: return false

	return true
