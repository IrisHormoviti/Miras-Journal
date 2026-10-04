extends Resource
class_name Setting

@export var player_name: String = "Local"
@export_category("Gameplay")
@export var auto_hide_hud: int = 0
@export var text_speed: int = 0
@export_category("Input")
@export var control_scheme_auto: bool = true
@export var control_scheme_enum: int = 0
@export var control_scheme_override: ControlScheme = null
@export var controller_vibration := true
@export var last_used_device: String = "Keyboard"
@export_category("Display")
@export var fullscreen := false
@export var upscaled_res := true
@export var upscale_factor: float = 1.0
@export var high_res_textures := false
@export var fps: int = 0
@export var vsync: bool = true
@export var glow_effect: bool = true
@export var blur_effect: bool = true
@export_category("Audio")
@export var master_volume: float = 0.0
@export var music_volume: float = 0.0
@export var sfx_volume: float = 0.0
@export var ui_volume: float = 0.0
@export var voices_volume: float = 0.0
@export var footsteps_volume: float = 0.0
@export_category("System")
@export var debug_mode: bool = false
