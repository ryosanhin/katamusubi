@tool
extends RefCounted

const ScopeIndex := preload("../scope_index.gd")
const TscnScanner := preload("../scanning/tscn_scanner.gd")

var _scope_index: ScopeIndex
var _is_rebuild_pending := false
## 一度[EditorFileSystem.filesystem_changed]で走査したシーンは同じシグナルで再走査しない。[br]
## 基本的に[update_scene_index]のタイミングだけで走査・更新する。
var _tracked_scene_paths: Dictionary[String, bool] = {}


func _init(init_scope_index: ScopeIndex) -> void:
	_scope_index = init_scope_index


func update_scene_index(path: String) -> void:
	var scene_uid := ResourceUID.path_to_uid(path)
	if scene_uid == path:
		push_warning("Could not obtain scene UID: %s" % path)
		return
	if _update_index(scene_uid):
		_tracked_scene_paths[path] = true
	else:
		_tracked_scene_paths.erase(path)


func synchronize_index_with_filesystem() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.is_scanning():
		return

	if _is_rebuild_pending:
		rebuild_all_index()
		return

	var root := filesystem.get_filesystem()
	if root != null:
		_synchronize_scene_paths(_get_scene_paths(root), false)


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
	
	_synchronize_scene_paths(_get_scene_paths(root), true)


## [EditorFileSystem] から得た一覧で追加・削除を反映する。全再構築時だけ既存シーンも読む。[br]
## [param scene_paths]: 走査対象のシーンパス[br]
## [param rebuild]: 全走査フラグ
func _synchronize_scene_paths(scene_paths: PackedStringArray, rebuild: bool) -> void:
	var existing_paths: Dictionary[String, bool] = {}
	var failed_paths: PackedStringArray = []

	for path in scene_paths:
		existing_paths[path] = true
		if not rebuild and _tracked_scene_paths.has(path):
			continue
		var scene_uid := ResourceUID.path_to_uid(path)
		if scene_uid == path:
			failed_paths.append(path)
			continue
		if not _update_index(scene_uid):
			failed_paths.append(path)
	
	_remove_index_in_deleted_scenes(existing_paths)

	var tracked_paths: Dictionary[String, bool] = {}
	for existing_path in existing_paths:
		if existing_path in failed_paths:
			continue
		tracked_paths[existing_path] = true

	_tracked_scene_paths = tracked_paths

	if not failed_paths.is_empty():
		push_warning(
				"Some scenes could not be scanned; their previous candidates were preserved:\n%s"
				% "\n".join(failed_paths)
		)


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


## 削除されていたシーンUIDに紐づいたインデックスを削除する。[br]
func _remove_index_in_deleted_scenes(
		existing_scene_paths: Dictionary[String, bool]
) -> void:
	var checked_scene_uid_set: Dictionary[StringName, bool] = {}
	var removed_scene_uid_set: Dictionary[StringName, bool] = {}

	for snapshot in _scope_index.scope_snapshots:
		var scene_uid := snapshot.scene_uid
		if checked_scene_uid_set.has(scene_uid):
			continue
		checked_scene_uid_set[scene_uid] = true

		var path := ResourceUID.ensure_path(scene_uid)
		if not existing_scene_paths.has(path):
			removed_scene_uid_set[scene_uid] = true

	for removed_scene_uid in removed_scene_uid_set:
		var empty: Array[ScopeSnapshot] = []
		_scope_index.replace_scene_snapshots(removed_scene_uid, empty)


## エディタが保持する一覧を使い、独自のディスク走査を行わずにtscnパスを収集する。[br]
## [param directory]: 走査するルートのディレクトリ[br]
## returns: 走査対象のディレクトリ以下の全tscnファイルのパス
func _get_scene_paths(directory: EditorFileSystemDirectory) -> PackedStringArray:
	var paths: PackedStringArray = []
	var dirs: Array[EditorFileSystemDirectory] = [directory]

	while not dirs.is_empty():
		var dir: EditorFileSystemDirectory = dirs.pop_back()
		for file_index in dir.get_file_count():
			if dir.get_file(file_index).get_extension().to_lower() == "tscn":
				paths.append(dir.get_file_path(file_index))
		
		for sub_dir_index in dir.get_subdir_count():
			dirs.append(dir.get_subdir(sub_dir_index))
	
	return paths
