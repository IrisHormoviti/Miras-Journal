extends PointLight2D

@export var min_in: float = 0
@export var max_in: float = 5
@export var min_out: float = 0
@export var max_out: float = 5

var timer: Timer = Timer.new()


func _ready() -> void:
	add_child(timer)
	timer.timeout.connect(timeout)
	timer.wait_time = randf_range(min_in, max_in)
	timer.start()


func timeout() -> void:
	if visible:
		hide()
		timer.wait_time = randf_range(max_out, max_out)
	else:
		show()
		timer.wait_time = randf_range(max_in, max_in)

	timer.start()
