extends Resource
class_name BattleMusicSet

@export var track: AudioStream
@export_group("TimeStamps")
@export var intro_end: float = 0
@export var battle_start: float = 0
@export var battle_loop: float = 0
@export var victory: float = 0
@export_group("Seprate tracks")
@export var victory_track: AudioStream
