extends Node
## A globally accessible manager for device-specific actions using SteamInput for any controller
## and standard Godot Input for the keyboard.
##
## All methods in this class that have a "device" parameter can accept -1
## which means the keyboard device.

# The actions defined in the Steam .vdf file are listed here
# with true or false indicating if input is analog or digital.
# False is digital (buttons), true is analog (joysticks, triggers, etc).
var action_names := {
	"Move": true,
	"Up": false,
	"Down": false,
	"Left": false,
	"Right": false,
	"Confirm": false,
	"Cancel": false,
	"Dash": false,
	"Overworld Attack": false,
	"Battle Attack": false,
	"Battle Ability": false,
	"Battle Item": false,
	"Battle Command": false,
	"Battle Escape": false,
	"Tab Left": false,
	"Tab Right": false,
	"Bag Menu": false,
	"Options Menu": false,
	"party Menu": false
}

# Track if we've gotten the handles yet.
var got_handles := false

# The action set handles and the current action set.
var game_action_set
var current_action_set

# Store the resulting handles for each action.
var actions = { }


## Call this after calling `Steam.inputInit()` and `Steam.enableDeviceCallbacks()`
func init() -> void:
	Steam.input_device_connected.connect(_on_steam_input_device_connected)
	Steam.input_device_disconnected.connect(_on_steam_input_device_disconnected)


func _on_steam_input_device_connected(input_handle: int) -> void:
	if not got_handles:
		get_handles()
	Steam.activateActionSet(input_handle, current_action_set)
	print("Device connected %s" % str(input_handle))


func _on_steam_input_device_disconnected(input_handle: int) -> void:
	print("Device disconnected %s" % str(input_handle))


func get_handles() -> void:
	got_handles = true
	game_action_set = Steam.getActionSetHandle("GameControls")
	current_action_set = game_action_set
	get_action_handles(action_names)


func get_action_handles(action_names: Dictionary) -> void:
	for action in action_names.keys():
		# If true, analog
		if action_names[action]:
			actions[action] = Steam.getAnalogActionHandle(action)
		else:
			actions[action] = Steam.getDigitalActionHandle(action)
