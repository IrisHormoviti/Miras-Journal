extends Resource
class_name Direction

static var UP: Direction:
	get: return from(Vector2.UP)
static var DOWN: Direction:
	get: return from(Vector2.DOWN)
static var LEFT: Direction:
	get: return from(Vector2.LEFT)
static var RIGHT: Direction:
	get: return from(Vector2.RIGHT)
static var CENTER: Direction:
	get: return from(Vector2.ZERO)

enum Ways {
	CENTER, UP, DOWN, LEFT, RIGHT
}

@export var way: Ways = Ways.CENTER:
	set(x):
		way = x
		var new_vector: Vector2 = way_to_vector(x)

		if vector != new_vector:
			vector = new_vector

var vector: Vector2 = Vector2.ZERO:
	set(x):
		var snapped_vec: Vector2 = snap_vector(x)
		vector = snapped_vec
		var new_way: Ways = vector_to_way(snapped_vec)

		if way != new_way:
			way = new_way

	get():
		return vector


static func from(vec: Vector2) -> Direction:
	var tor := snap_vector(vec)

	var dir: Direction = Direction.new()
	dir.vector = tor
	return dir


static func way_to_vector(x: Ways) -> Vector2:
	match x:
		Ways.UP: return Vector2.UP
		Ways.DOWN: return Vector2.DOWN
		Ways.LEFT: return Vector2.LEFT
		Ways.RIGHT: return Vector2.RIGHT
		_: return Vector2.ZERO


static func from_way(x: Ways) -> Direction:
	return from(way_to_vector(x))


static func vector_to_way(vec: Vector2) -> Ways:
	match vec:
		Vector2.UP: return Ways.UP
		Vector2.DOWN: return Ways.DOWN
		Vector2.LEFT: return Ways.LEFT
		Vector2.RIGHT: return Ways.RIGHT
		_: return Ways.CENTER


static func snap_vector(v: Vector2, allow_zero := true) -> Vector2:
	if v == Vector2.ZERO and allow_zero: return Vector2.ZERO
	if abs(v.x) > abs(v.y):
		if v.x > 0:
			return Vector2.RIGHT
		else:
			return Vector2.LEFT
	else:
		if v.y > 0:
			return Vector2.DOWN
		else:
			return Vector2.UP


static func get_letter_from_vector(d: Vector2) -> String:
	match snap_vector(d):
		Vector2.RIGHT:
			return "R"

		Vector2.LEFT:
			return "L"

		Vector2.UP:
			return "U"

		Vector2.DOWN:
			return "D"

		_: return "C"


func get_letter() -> String:
	match vector:
		Vector2.RIGHT:
			return "R"

		Vector2.LEFT:
			return "L"

		Vector2.UP:
			return "U"

		Vector2.DOWN:
			return "D"

		_: return "C"


static func from_letter(d: String) -> Direction:
	match d:
		"R", "Right":
			return RIGHT

		"L", "Left":
			return LEFT

		"U", "Up":
			return UP

		"D", "Down":
			return DOWN

		_:
			return CENTER


static func vector_to_string(d: Vector2) -> String:
	var dir := snap_vector(d)

	if dir == Vector2.RIGHT:
		return "Right"
	elif dir == Vector2.LEFT:
		return "Left"
	elif dir == Vector2.UP:
		return "Up"
	elif dir == Vector2.DOWN:
		return "Down"
	else: return "Center"


func _to_string() -> String:
	match vector:
		Vector2.RIGHT:
			return "Right"

		Vector2.LEFT:
			return "Left"

		Vector2.UP:
			return "Up"

		Vector2.DOWN:
			return "Down"

		_: return "Center"


func equals(dir: Direction) -> bool:
	return vector == dir.vector


func is_vector(dir: Vector2) -> bool:
	return vector == dir


func is_letter(string: String) -> bool:
	return get_letter() == string


func set_to(vec: Vector2) -> void:
	vector = snap_vector(vec)


func is_horizontal() -> bool:
	return abs(vector.x) > abs(vector.y)


func is_vertical() -> bool:
	return abs(vector.x) < abs(vector.y)


func oposite() -> Direction:
	var result := self.duplicate()
	result.vector = result.vector * -1
	return result
