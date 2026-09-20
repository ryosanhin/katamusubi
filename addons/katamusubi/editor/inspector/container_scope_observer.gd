@tool
extends RefCounted

const ScopeIndex := preload("../scope_index.gd")
const TscnScanner := preload("../scanning/tscn_scanner.gd")

var _scope_index: ScopeIndex
var _rescan_after_filesystem_scan := false


func _init(init_scope_index: ScopeIndex) -> void:
	_scope_index = init_scope_index


func on_scene_saved(path: String) -> void:
	var scene_uid := ResourceUID.path_to_uid(path)
	if scene_uid == path:
		push_warning("Could not obtain scene UID: %s" % path)
		return
	_update_scene(scene_uid)
	_save_index()


func on_filesystem_changed() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	if _rescan_after_filesystem_scan:
		if filesystem.is_scanning():
			return
		_rescan_after_filesystem_scan = false
		rescan_all_scenes()
		return

	if _remove_deleted_scenes():
		_save_index()


## Rebuilds the cache from every saved scene, including scenes absent from the cache.
func rescan_all_scenes() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.is_scanning():
		_rescan_after_filesystem_scan = true
		return

	var root := filesystem.get_filesystem()
	if root == null:
		return
	var scene_paths: PackedStringArray = []
	_collect_scene_paths(root, scene_paths)
	var failed: PackedStringArray = []
	for path in scene_paths:
		var scene_uid := ResourceUID.path_to_uid(path)
		if scene_uid == path or not _update_scene(scene_uid):
			failed.append(path)
	_remove_deleted_scenes()
	_save_index()
	if not failed.is_empty():
		push_warning("Some scenes could not be scanned; their previous candidates were preserved:\n%s" % "\n".join(failed))


func _update_scene(scene_uid: StringName) -> bool:
	var result := TscnScanner.scan(scene_uid)
	if not result.succeeded:
		push_warning(result.error_message)
		return false
	_scope_index.replace_scene_snapshots(scene_uid, result.entries)
	return true


func _save_index() -> void:
	var error := _scope_index.save()
	if error != OK:
		# The cache is advisory: never roll scene settings back or prevent running.
		push_warning("Failed to save scope candidate cache: %s" % error_string(error))
		return
	EditorInterface.get_resource_filesystem().scan()


func _remove_deleted_scenes() -> bool:
	var removed_scene_uid_set: Dictionary[StringName, bool] = {}
	for candidate in _scope_index.scope_snapshots:
		var path := ResourceUID.ensure_path(candidate.scene_uid)
		if path.is_empty() or not FileAccess.file_exists(path):
			removed_scene_uid_set[candidate.scene_uid] = true

	for removed_scene_uid in removed_scene_uid_set:
		var empty: Array[ScopeSnapshot] = []
		_scope_index.replace_scene_snapshots(removed_scene_uid, empty)
	return not removed_scene_uid_set.is_empty()


func _collect_scene_paths(directory: EditorFileSystemDirectory, output: PackedStringArray) -> void:
	for file_index in directory.get_file_count():
		if directory.get_file_type(file_index) == "PackedScene":
			output.append(directory.get_file_path(file_index))
	for subdirectory_index in directory.get_subdir_count():
		_collect_scene_paths(directory.get_subdir(subdirectory_index), output)
