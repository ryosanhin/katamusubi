@tool
extends RefCounted

const ScopeIndex := preload("../scope_index.gd")
const ScopeIndexStorage := preload("../scope_index_storage.gd")
const TscnScanner := preload("../scanning/tscn_scanner.gd")

var _scope_index: ScopeIndex
var _storage: ScopeIndexStorage
var _is_rebuild_pending := false


func _init(storage_path: String = ScopeIndexStorage.PATH) -> void:
	_storage = ScopeIndexStorage.new(storage_path)
	_scope_index = _storage.get_index()
	_is_rebuild_pending = _storage.needs_rebuild


func get_scope_index() -> ScopeIndex:
	return _scope_index


func rebuild_index_if_needed() -> void:
	if _is_rebuild_pending:
		rebuild_all_index()


func update_scene_index(path: String) -> void:
	var scene_uid := ResourceUID.path_to_uid(path)
	if scene_uid == path:
		push_warning("Could not obtain scene UID: %s" % path)
		return
	_update_index(scene_uid)
	_save_index()


func synchronize_index_with_filesystem() -> void:
	if _storage.ensure_available():
		_is_rebuild_pending = true

	if _is_rebuild_pending:
		rebuild_all_index()
		return

	if _remove_index_in_deleted_scenes():
		_save_index()


## プロジェクト内全シーンについて走査しインデックスを再構築する。
func rebuild_all_index() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	# ファイルシステムがスキャン中には邪魔しない。
	# どうせファイルシステム完了後に構築を割り込ませるタイミングがあるので。
	if filesystem.is_scanning():
		_is_rebuild_pending = true
		return
	
	_is_rebuild_pending = false

	var root := filesystem.get_filesystem()
	if root == null:
		return
	var scene_paths := _get_scene_paths(root)
	var failed: PackedStringArray = []
	for path in scene_paths:
		var scene_uid := ResourceUID.path_to_uid(path)
		if scene_uid == path or not _update_index(scene_uid):
			failed.append(path)
	
	_remove_index_in_deleted_scenes()
	
	_save_index()

	if not failed.is_empty():
		push_warning("Some scenes could not be scanned; their previous candidates were preserved:\n%s" % "\n".join(failed))


## あるシーンに存在するスコープを更新する。[br]
## [param scene_uid]: 走査対象のシーンUID[br]
## returns: 成功したか
func _update_index(scene_uid: StringName) -> bool:
	var scene_snapshot := TscnScanner.scan(scene_uid)
	if not scene_snapshot.succeeded:
		push_warning(scene_snapshot.error_message)
		return false
	_scope_index.replace_scene_snapshots(scene_uid, scene_snapshot.entries)
	return true


## インデックスを保存する。
func _save_index() -> void:
	var error := _storage.save()
	if error != OK:
		push_warning("Failed to save scope candidate cache: %s" % error_string(error))
		return
	EditorInterface.get_resource_filesystem().scan()


## 削除されていたシーンUIDに紐づいたインデックスを削除する。[br]
## returns: 削除したか。
func _remove_index_in_deleted_scenes() -> bool:
	var removed_scene_uid_set: Dictionary[StringName, bool] = {}
	for candidate in _scope_index.scope_snapshots:
		var path := ResourceUID.ensure_path(candidate.scene_uid)
		if path.is_empty() or not FileAccess.file_exists(path):
			removed_scene_uid_set[candidate.scene_uid] = true

	for removed_scene_uid in removed_scene_uid_set:
		var empty: Array[ScopeSnapshot] = []
		_scope_index.replace_scene_snapshots(removed_scene_uid, empty)
	return not removed_scene_uid_set.is_empty()


## あるディレクトリを起点にそれ以下の全てのtscnファイルのパスを収集する。
func _get_scene_paths(directory: EditorFileSystemDirectory) -> PackedStringArray:
	var paths: PackedStringArray = []
	var dirs: Array[EditorFileSystemDirectory] = []
	dirs.append(directory)

	while not dirs.is_empty():
		var dir: EditorFileSystemDirectory = dirs.pop_back()
		for file_index in dir.get_file_count():
			if dir.get_file(file_index).get_extension() == "tscn":
				paths.append(dir.get_file_path(file_index))
		
		for sub_dir_index in dir.get_subdir_count():
			dirs.append(dir.get_subdir(sub_dir_index))
	
	return paths
