@tool
extends RefCounted

const ScopeIndex := preload("scope_index.gd")
const TscnScanner := preload("scanning/tscn_scanner.gd")

var _scope_index: ScopeIndex


func _init(init_scope_index: ScopeIndex) -> void:
	_scope_index = init_scope_index


func on_scene_saved(path: String) -> void:
	var uid := ResourceUID.path_to_uid(path)
	if uid == path:
		push_warning("Could not obtain scene UID: %s" % path)
		return
	_update_scene(uid)


func on_filesystem_changed() -> void:
	var removed: Dictionary[StringName, bool] = {}
	for candidate in _scope_index.scope_snapshots:
		var path := ResourceUID.ensure_path(candidate.scene_uid)
		if path.is_empty() or not FileAccess.file_exists(path):
			removed[candidate.scene_uid] = true
	for uid in removed:
		var empty: Array[ScopeSnapshot] = []
		_scope_index.replace_scene_snapshots(uid, empty)
	if not removed.is_empty():
		_save_index()


## Rebuilds the cache from every saved scene, including scenes absent from the cache.
func rescan_all_scenes() -> void:
	var scene_paths: PackedStringArray = []
	_collect_scene_paths("res://", scene_paths)
	var failed: PackedStringArray = []
	for path in scene_paths:
		var uid := ResourceUID.path_to_uid(path)
		if uid == path or not _update_scene(uid, false):
			failed.append(path)
	_save_index()
	if not failed.is_empty():
		push_warning("Some scenes could not be scanned; their previous candidates were preserved:\n%s" % "\n".join(failed))


func _update_scene(uid: StringName, save_after := true) -> bool:
	var result := TscnScanner.scan(uid)
	if not result.succeeded:
		push_warning(result.error_message)
		return false
	_scope_index.replace_scene_snapshots(uid, result.entries)
	if save_after:
		_save_index()
	return true


func _save_index() -> void:
	var error := _scope_index.save()
	if error != OK:
		# The cache is advisory: never roll scene settings back or prevent running.
		push_warning("Failed to save scope candidate cache: %s" % error_string(error))
		return
	EditorInterface.get_resource_filesystem().scan()


func _collect_scene_paths(directory_path: String, output: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			if not entry.begins_with("."):
				_collect_scene_paths(path, output)
		elif entry.get_extension() == "tscn":
			output.append(path)
		entry = directory.get_next()
