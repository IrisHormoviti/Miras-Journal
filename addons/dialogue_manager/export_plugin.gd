class_name DMExportPlugin extends EditorExportPlugin

const IGNORED_PATHS: PackedStringArray = [
	"/assets",
	"/components",
	"/views",
	"inspector_plugin",
	"test_scene"
]


func _get_name() -> String:
	return "Dialogue Manager Export Plugin"


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	var plugin_path: String = DMPlugin.get_plugin_path()

	# Ignore any editor stuff
	for ignored_path: String in IGNORED_PATHS:
		if path.begins_with(plugin_path + ignored_path):
			skip()

	# Ignore C# stuff if not using dotnet
	if path.begins_with(plugin_path) and not DMSettings.check_for_dotnet_solution():
		if path.ends_with(".cs"):
			skip()
		
		# Scenes that reference C# scripts cause the export to crash without dotnet
		elif path.ends_with(".tscn") and _has_dotnet_dependency(path):
			skip()


func _has_dotnet_dependency(path: String) -> bool:
	for dependency: String in ResourceLoader.get_dependencies(path):
		if dependency.ends_with(".cs"):
			return true
	return false
