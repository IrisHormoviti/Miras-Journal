extends CanvasLayer
class_name Transition

static var active_transitions: Array[Transition] = []

@onready var animation_player: AnimationPlayer = $AnimationPlayer
var exit_animation := "RESET"
var exit_in_reverse := false


## Preform a wipe transition towards a direction
## If called with no arguments, it will wipe towards the player's direction
## call unwipe() to end the transition
static func wipe(dir: Direction = Global.player.facing if Global.player else Direction.RIGHT) -> void:
	if not dir or dir.is_vector(Vector2.ZERO):
		return

	var transition_name := "wipe_" + dir.to_string().to_lower()
	var exit_transition_name := "wipe_" + dir.oposite().to_string().to_lower()
	await add_wipe_transition(transition_name, exit_transition_name)


## 4 black squares close in to the center
static func close_in() -> void:
	await add_wipe_transition("close_in", "close_in")


static func load_icon() -> void:
	add_icon_transition("load", "close")


static func load_icon_close() -> void:
	for i in active_transitions:
		if i and i.exit_animation == "close":
			i.exit()


static func save_icon() -> void:
	(await add_icon_transition("save", "RESET")).exit()


static func fade_in_gray(opacity := 0.8) -> Transition:
	return await fade_in(Color(1,1,1, opacity))


static func fade_in(color := Color.BLACK, in_time := 0.3) -> Transition:
	const transition_name := "fade"
	const exit_transition_name := "fade"

	var transition: Transition = preload("res://UI/Transition/FadeTransition.tscn").instantiate()
	transition.name = transition_name + "_" + str(randi())
	transition.exit_animation = exit_transition_name
	transition.exit_in_reverse = true
	transition.get_node("Fade").color = color
	Global.get_tree().root.add_child(transition)

	var anim_length := transition.animation_player.get_animation(transition_name).length
	var in_speed := anim_length / in_time

	transition.animation_player.speed_scale = in_speed
	transition.play_animation(transition_name)

	print("Fade Transition: ", transition_name + " > ", exit_transition_name)

	active_transitions.append(transition)
	await transition.animation_player.animation_finished
	return transition


static func fade_in_out(color: Color = Color.BLACK, in_time := 0.3, out_time := 0.3, wait_time := 0.0) -> void:
	const transition_name := "fade"
	const exit_transition_name := "fade"

	var transition: Transition = preload("res://UI/Transition/FadeTransition.tscn").instantiate()
	transition.name = transition_name + "_" + str(randi())
	transition.exit_animation = exit_transition_name
	transition.exit_in_reverse = true
	transition.get_node("Fade").color = color
	Global.get_tree().root.add_child(transition)

	var anim_length := transition.animation_player.get_animation(transition_name).length
	var in_speed := anim_length / in_time

	transition.animation_player.speed_scale = in_speed
	transition.play_animation(transition_name)

	print("Fade Transition: ", transition_name + " > ", exit_transition_name)

	await transition.animation_player.animation_finished
	if wait_time > 0:
		await Event.wait(wait_time)

	var out_speed := anim_length / out_time
	transition.animation_player.speed_scale = out_speed
	await transition.exit()


static func fade_out(out_time := 0.3) -> void:
	for transition in active_transitions:
		if transition and transition.name.begins_with("fade"):

			var anim_length := transition.animation_player.get_animation("fade").length
			var out_speed := anim_length / out_time

			transition.animation_player.speed_scale = out_speed
			active_transitions.erase(transition)
			await transition.exit()


static func flip_time(from: Event.TOD, to: Event.TOD) -> void:
	const transition_name := "flip_time"
	const exit_transition_name := "wipe_right"

	var transition: Transition = preload("res://UI/Transition/TimeTransition.tscn").instantiate()
	transition.name = transition_name + "_" + str(randi())
	transition.exit_animation = exit_transition_name
	transition.exit_in_reverse = true

	transition.get_node("TimeBefore").hide()
	transition.get_node("TimeAfter").hide()
	transition.get_node("TimeBefore").text = Query.to_tod_text(from)
	transition.get_node("TimeAfter").text = Query.to_tod_text(to)
	transition.get_node("TimeBefore").icon = await Query.to_tod_icon(from)
	transition.get_node("TimeAfter").icon = await Query.to_tod_icon(to)

	Global.get_tree().root.add_child(transition)
	active_transitions.append(transition)
	transition.play_animation(transition_name)

	print("Time Transition: ", transition_name)

	await transition.animation_player.animation_finished


## Adds a transition of a specific name in the animation_player to the scene tree
## They stay there until unwipe() is called
static func add_wipe_transition(transition_name: String, exit_transition_name := "RESET") -> Transition:
	#push_warning(transition_name)
	var transition: Transition = preload("res://UI/Transition/WipeTransition.tscn").instantiate()
	transition.name = transition_name + "_" + str(randi())
	transition.exit_animation = exit_transition_name
	transition.exit_in_reverse = true
	Global.get_tree().root.add_child(transition)
	transition.play_animation(transition_name)
	active_transitions.append(transition)

	print("Wipe Transition: ", transition_name + " > ", exit_transition_name)

	await transition.animation_player.animation_finished
	return transition


## End any wipe transitions started with add_wipe_transition()
static func unwipe() -> void:
	for transition in active_transitions:
		if transition and (
			transition.exit_animation.begins_with("wipe") or
			transition.exit_animation == "close_in"
		):
			active_transitions.erase(transition)
			await transition.exit()


## Adds a transition of a specific name in the animation_player to the scene tree
## They stay there until unwipe() is called
static func add_icon_transition(transition_name: String, exit_transition_name := "Close") -> Transition:
	#push_warning(transition_name)
	var transition := preload("res://UI/Transition/IconTransition.tscn").instantiate()
	transition.name = transition_name + "_" + str(randi())
	transition.exit_animation = exit_transition_name
	Global.get_tree().root.add_child(transition)
	transition.play_animation(transition_name)
	active_transitions.append(transition)

	print("Icon Transition: ", transition_name + " > ", exit_transition_name)

	await transition.animation_player.animation_finished
	return transition


func play_animation(anim: String) -> void:
	animation_player.play(anim)


func exit() -> void:
	if exit_in_reverse:
		animation_player.play_backwards(exit_animation)
	else:
		animation_player.play(exit_animation)

	await animation_player.animation_finished
	queue_free()
