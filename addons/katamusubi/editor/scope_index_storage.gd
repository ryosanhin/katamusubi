@tool
extends RefCounted

signal save_requested

const ScopeIndex := preload("scope_index.gd")

var _path: String
var _index: ScopeIndex
var _dirty := false


## pathには[code]res://[/code]、[code]user://[/code]、または絶対パスを指定する。
## ファイル名の拡張子は.tresとする。
func _init(path: String) -> void:
	_path = path

	# このインスタンスをObserverとInspectorで共有し続ける。
	_index = ScopeIndex.new()
	_index.format_version = ScopeIndex.CURRENT_FORMAT_VERSION

	if not _try_load_cache():
		# 再構築結果が空でも、空の正常なキャッシュを保存できるようにする。
		_dirty = true

	_index.changed.connect(_on_index_changed)


func get_index() -> ScopeIndex:
	return _index


func is_dirty() -> bool:
	return _dirty


## 未保存の変更がある場合だけ保存する。
## 失敗した場合はdirtyを維持する。
func save() -> Error:
	if not _dirty:
		return OK

	if not _path.is_absolute_path() or _path.get_extension() != "tres":
		return ERR_FILE_BAD_PATH

	var error := DirAccess.make_dir_recursive_absolute(
		_path.get_base_dir()
	)
	if error != OK:
		return error

	# ResourceSaverが形式を判定できるように末尾を.tresにする。
	var tmp_path := _path.get_basename() + ".tmp.tres"

	error = ResourceSaver.save(_index, tmp_path)
	if error != OK:
		return error

	# 本体を事前に削除せず、一時ファイルから置き換える。
	error = DirAccess.rename_absolute(tmp_path, _path)
	if error != OK:
		return error

	_dirty = false
	return OK


func _try_load_cache() -> bool:
	if not FileAccess.file_exists(_path):
		return false

	var loaded := ResourceLoader.load(
		_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as ScopeIndex

	if loaded == null:
		push_warning("Could not load scope index cache: %s" % _path)
		return false

	if not _is_valid_cache(loaded):
		push_warning("Scope index cache needs rebuilding: %s" % _path)
		return false

	# 共有用の_index自体は置き換えない。
	_index.scope_snapshots.assign(loaded.scope_snapshots)
	return true


func _is_valid_cache(index: ScopeIndex) -> bool:
	if index.format_version != ScopeIndex.CURRENT_FORMAT_VERSION:
		return false

	for snapshot in index.scope_snapshots:
		if snapshot == null or snapshot.scope_id.is_empty():
			return false

		if ResourceUID.text_to_id(snapshot.scene_uid) == ResourceUID.INVALID_ID:
			return false

	# UIDが現在のファイルに対応するかは、
	# エディタのファイルシステムスキャン完了後に確認する。
	return true


func _on_index_changed() -> void:
	_dirty = true
	save_requested.emit()
