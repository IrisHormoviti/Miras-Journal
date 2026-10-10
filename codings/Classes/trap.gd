extends State
class_name Trap

## A Trap is a State that lies in wait on an Actor. When that Actor is hit in
## battle and the incoming attack meets `condition`, the trap activates.
## it interrupts the attacker's current ability and the trap's owner performs
## `ability` instead.

## Traps are set up by abilities that reference one in their SetsTrap property,
## usually through the "SetTrap" action sequence.

## The ability performed when the trap activates
@export var ability: Ability = null

## Determines which hits spring the trap. If null, any damaging hit does
@export var condition: TrapCondition = null

## If true, the trap is removed from its owner once used
@export var consume_on_trigger := true

## Who the trap's ability is aimed at when it springs
enum Aim {
	ATTACKER, ## Whoever sprung the trap
	OWNER, ## The actor the trap was placed on
}

## Who the trap's ability is aimed at
@export var aim: Aim = Aim.ATTACKER


## Returns true if the trap's ability is aimed at whoever sprung it
func aims_at_attacker() -> bool:
	return aim == Aim.ATTACKER
