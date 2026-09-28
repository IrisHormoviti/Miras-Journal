extends Node

@export_multiline() var flag: String = ""
@export var also_hide_on_reserved_dates := false
@export var hide_if: bool = true
@export var use_sprite := false
@export var free_instead := false


func _ready() -> void:
	check()
	get_parent().show()
	Global.check.connect(check)


func condition() -> bool:
	if also_hide_on_reserved_dates and Event.date_is_reserved():
		return true

	if Event.f(flag) == hide_if:
		return true

	return false


func check() -> void:
	if get_node_or_null("Sprite") != null: use_sprite = true
	if flag == "": return

	if condition():
		if use_sprite:
			if $Sprite.animation != "hide": $Sprite.play("hide")
		elif free_instead:
			get_parent().queue_free()
		else:
			get_parent().hide()

		for i in get_parent().get_children():
			if i is CollisionShape2D: i.set_deferred("disabled", true)
	else:
		if use_sprite:
			if $Sprite.animation != "default": $Sprite.play("default")

		for i in get_parent().get_children():
			if i is CollisionShape2D: i.set_deferred("disabled", false)
