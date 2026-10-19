@tool
extends Resource
class_name ValueRef

enum Mode {
	FIXED,
	ABILITY_PARAMETER,
	ITEM_PARAMETER,
	WEAPON_POWER,
	CALCULATED_DAMAGE,
	CALCULATED_HEAL,
	MAX_HP,
	MAX_AURA,
	CURRENT_HP,
	CURRENT_AURA,
	MISSING_HP,
	MAX_HP_PERCENT,
	MAX_AURA_PERCENT,
	STATE_COUNT,
	DAMAGE_RECEIVED_THIS_TURN,
	RANDOM_INT,
	RANDOM_FLOAT,
}

@export var mode: Mode = Mode.FIXED:
	set(value):
		mode = value
		notify_property_list_changed()
@export var actor: ActorRef
@export var value: float = 0.0
## Applied to the computed value, so `0.5` represents half damage.
@export var multiplier: float = 1.0
## Added after the multiplier.
@export var add: float = 0.0
@export var random_min: float = 0.0
@export var random_max: float = 1.0


func resolve(ctx: ActionSequenceContext) -> float:
	var subject := ctx.target
	if actor != null:
		subject = actor.resolve(ctx)

	var result := value

	match mode:
		Mode.FIXED:
			pass
		Mode.ABILITY_PARAMETER:
			if ctx.ability != null:
				result = float(ctx.ability.Parameter)
		Mode.ITEM_PARAMETER:
			if ctx.item != null:
				result = float(ctx.item.Parameter)
		Mode.WEAPON_POWER:
			if ctx.caster != null and ctx.caster.Weapon != null:
				result = float(ctx.caster.Weapon.power)
		Mode.CALCULATED_DAMAGE:
			result = float(Query.calc_num(ctx.ability, ctx.caster))
		Mode.CALCULATED_HEAL:
			result = float(Query.calc_num(ctx.ability, ctx.caster))
			if ctx.caster != null:
				result *= float(int(ctx.caster.Magic * ctx.caster.MagicMultiplier))
		Mode.MAX_HP:
			if subject != null:
				result = float(subject.MaxHP)
		Mode.MAX_AURA:
			if subject != null:
				result = float(subject.MaxAura)
		Mode.CURRENT_HP:
			if subject != null:
				result = float(subject.Health)
		Mode.CURRENT_AURA:
			if subject != null:
				result = float(subject.Aura)
		Mode.MISSING_HP:
			if subject != null:
				result = float(subject.MaxHP - subject.Health)
		Mode.MAX_HP_PERCENT:
			if subject != null:
				result = float(subject.MaxHP) * value / 100.0
		Mode.MAX_AURA_PERCENT:
			if subject != null:
				result = float(subject.MaxAura) * value / 100.0
		Mode.STATE_COUNT:
			result = float(subject.States.size()) if subject != null else 0.0
		Mode.DAMAGE_RECEIVED_THIS_TURN:
			result = float(subject.DamageRecivedThisTurn) if subject != null else 0.0
		Mode.RANDOM_INT:
			result = float(randi_range(int(random_min), int(random_max)))
		Mode.RANDOM_FLOAT:
			result = randf_range(random_min, random_max)

	return result * multiplier + add


func _to_string() -> String:
	var label := ""

	match mode:
		Mode.FIXED:
			label = str(value)
		Mode.ABILITY_PARAMETER:
			label = "ability power"
		Mode.ITEM_PARAMETER:
			label = "item power"
		Mode.WEAPON_POWER:
			label = "weapon power"
		Mode.CALCULATED_DAMAGE, Mode.CALCULATED_HEAL:
			label = ""
		Mode.MAX_HP:
			label = "max hp"
		Mode.MAX_AURA:
			label = "max aura"
		Mode.CURRENT_HP:
			label = "current hp"
		Mode.CURRENT_AURA:
			label = "current aura"
		Mode.MISSING_HP:
			label = "missing hp"
		Mode.MAX_HP_PERCENT:
			label = "max hp %"
		Mode.MAX_AURA_PERCENT:
			label = "max aura %"
		Mode.STATE_COUNT:
			label = "state count"
		Mode.DAMAGE_RECEIVED_THIS_TURN:
			label = "damage taken"
		Mode.RANDOM_INT:
			label = "random int"
		Mode.RANDOM_FLOAT:
			label = "random float"

	if not is_equal_approx(multiplier, 1.0):
		label += " x%s" % str(multiplier)

	if not is_zero_approx(add):
		label += " +%s" % str(add)

	return label.strip_edges()


func _validate_property(property: Dictionary) -> void:
	var visible: Array[String] = ["mode", "multiplier", "add"]
	match mode:
		Mode.FIXED:
			visible.append("value")
		Mode.ABILITY_PARAMETER, Mode.ITEM_PARAMETER, Mode.WEAPON_POWER, Mode.CALCULATED_DAMAGE, Mode.CALCULATED_HEAL:
			pass
		Mode.MAX_HP, Mode.MAX_AURA, Mode.CURRENT_HP, Mode.CURRENT_AURA, Mode.MISSING_HP, Mode.STATE_COUNT, Mode.DAMAGE_RECEIVED_THIS_TURN:
			visible.append("actor")
		Mode.MAX_HP_PERCENT, Mode.MAX_AURA_PERCENT:
			visible.append_array(["actor", "value"])
		Mode.RANDOM_INT, Mode.RANDOM_FLOAT:
			visible.append_array(["random_min", "random_max"])
	StepEditor.only(property, visible)
