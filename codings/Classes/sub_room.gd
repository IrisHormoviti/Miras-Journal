@icon("res://art/Icons/Enemies/Object.png")
extends Node2D
class_name SubRoom

@export var Title: String
@export var lock_cam := true
@export var cam_pos: Vector2
@export var cam_zoom: float = 4
@export var cant_dash_inside := true
var Layers: Array[TileMapLayer]
var t: Tween


func _ready() -> void:
	if position != Vector2.ZERO: push_warning(name, " is not at position 0,0")
	modulate = Color.TRANSPARENT
	hide()
	for i in get_children():
		if i is TileMapLayer:
			Layers.append(i)
			i.collision_enabled = false


func transition(time := 0.3) -> void:
	Global.room.current_subroom = self
	show()
	if is_instance_valid(t): t.kill()
	t = create_tween()
	t.set_parallel()
	t.tween_property(self, "modulate", Color.WHITE, time)
	Global.room.fade()
	Global.player.z_index = z_index
	Event.teleport_followers()
	if cant_dash_inside: Global.player.can_dash = false
	if lock_cam:
		Global.player.camera_follow(false)
		Global.camera.position = cam_pos

	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property(Global.camera, "zoom", Vector2(cam_zoom, cam_zoom), time)
	for i in get_children(): if i is TileMapLayer: i.collision_enabled = true
	await t.finished
	for i in Layers:
		i.material = preload("res://codings/Shaders/Pixelart.tres")
		i.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func detransition() -> void:
	Global.room.current_subroom = null
	Global.room.unfade()
	Global.room.setup_zoom(true)
	if cant_dash_inside: Global.player.can_dash = true
	Global.player.camera_follow(true)
	await fade_out()
	hide()
	for i in get_children(): if i is TileMapLayer: i.collision_enabled = false
	Event.teleport_followers()
	Global.player.z_index = Global.room.z_index

	if Global.room.current_subroom == self:
		Event.take_control(true, true)
		await transition()
		Event.give_control(false)


func fade_out() -> void:
	if is_instance_valid(t): t.kill()
	t = create_tween()
	t.tween_property(self, "modulate", Color.TRANSPARENT, 0.2)
	for i in Layers:
		i.material = null
		i.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	await t.finished
	hide()
	for i in get_children(): if i is TileMapLayer: i.collision_enabled = false
