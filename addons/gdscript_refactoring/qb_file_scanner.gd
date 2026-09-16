@tool
extends RefCounted

## Recursively walks the Godot project filesystem and returns
## the absolute (globalized) paths of all .gd files found.


func collect_gd_files(root_path: String) -> PackedStringArray:
	var results := PackedStringArray()
	_scan_dir(root_path, results)
	return results


func _scan_dir(path: String, results: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("GDScript Renamer – cannot open directory: %s" % path)
		return

	dir.include_hidden       = false
	dir.include_navigational = false

	dir.list_dir_begin()
	var entry := dir.get_next()

	while entry != "":
		if entry.begins_with(".") or entry == ".godot":
			entry = dir.get_next()
			continue

		var full_path := path.path_join(entry)

		if dir.current_is_dir():
			_scan_dir(full_path, results)
		elif entry.ends_with(".gd"):
			results.append(ProjectSettings.globalize_path(full_path))

		entry = dir.get_next()

	dir.list_dir_end()
