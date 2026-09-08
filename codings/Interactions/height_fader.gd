extends TileMapLayer

@export var x := 0
@export var should_be_greater_than_x := false
@export var y := 0
@export var should_be_greater_than_y := false
var t: Tween
var is_hidden := false
var lock := false
var camera_index := -1


func _ready() -> void:
	if camera_index != -1 and camera_index != Global.room.index:
		process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if Global.player == null: return
	var pos := Global.player.position
	var to_hide: bool = (
		(pos.y > y == should_be_greater_than_y or y == 0) and
		(pos.x > x == should_be_greater_than_x or x == 0)
	)

	if to_hide != is_hidden:
		if is_instance_valid(t): t.kill()
		t = create_tween()

		if to_hide:
			is_hidden = true
			t.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
		else:
			is_hidden = false
			t.tween_property(self, "modulate", Color.WHITE, 0.3)
