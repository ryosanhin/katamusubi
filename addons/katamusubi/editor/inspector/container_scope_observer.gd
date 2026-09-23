@tool
extends RefCounted

const ScopeIndex := preload("../scope_index.gd")
const TscnScanner := preload("../scanning/tscn_scanner.gd")

var _scope_index: ScopeIndex
var _is_rebuild_pending := false


func _init(init_scope_index: ScopeIndex) -> void:
	_scope_index = init_scope_index


func update_scene_index(path: String) -> void:
	var scene_uid := ResourceUID.path_to_uid(path)
	if scene_uid == path:
		push_warning("Could not obtain scene UID: %s" % path)
		return
	_update_index(scene_uid)


func synchronize_index_with_filesystem() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.is_scanning():
		return

	if _is_rebuild_pending:
		rebuild_all_index()
		return

	_remove_index_in_deleted_scenes()


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
		if scene_uid == path:
			failed.append(path)
			continue
		if not _update_index(scene_uid):
			failed.append(path)
	
	_remove_index_in_deleted_scenes()

	if not failed.is_empty():
		push_warning(
				"Some scenes could not be scanned; their previous candidates were preserved:\n%s"
				% "\n".join(failed)
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
## returns: 削除したか。
func _remove_index_in_deleted_scenes() -> void:
	var checked_scene_uid_set: Dictionary[StringName, bool] = {}
	var removed_scene_uid_set: Dictionary[StringName, bool] = {}

	for snapshot in _scope_index.scope_snapshots:
		var scene_uid := snapshot.scene_uid
		if checked_scene_uid_set.has(scene_uid):
			continue
		checked_scene_uid_set[scene_uid] = true

		var path := ResourceUID.ensure_path(scene_uid)
		if path.is_empty() or not FileAccess.file_exists(path):
			removed_scene_uid_set[scene_uid] = true

	for removed_scene_uid in removed_scene_uid_set:
		var empty: Array[ScopeSnapshot] = []
		_scope_index.replace_scene_snapshots(removed_scene_uid, empty)


## あるディレクトリを起点にそれ以下の全てのtscnファイルのパスを収集する。
func _get_scene_paths(directory: EditorFileSystemDirectory) -> PackedStringArray:
	var paths: PackedStringArray = []
	var dirs: Array[EditorFileSystemDirectory] = [directory]

	while not dirs.is_empty():
		var dir: EditorFileSystemDirectory = dirs.pop_back()
		for file_index in dir.get_file_count():
			if dir.get_file(file_index).get_extension() == "tscn":
				paths.append(dir.get_file_path(file_index))
		
		for sub_dir_index in dir.get_subdir_count():
			dirs.append(dir.get_subdir(sub_dir_index))
	
	return paths
