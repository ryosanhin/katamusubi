@tool
extends RefCounted
## 再生成可能なスコープ索引を、アドオン本体とは別の場所に保管する。

const ScopeIndex := preload("scope_index.gd")

const PATH := "res://.godot/katamusubi/scope_index.tres"

var _index: ScopeIndex = ScopeIndex.new()
var _path: String
var needs_rebuild := false


func _init(storage_path: String = PATH) -> void:
	_path = storage_path
	_load_or_generate()


func get_index() -> ScopeIndex:
	return _index


## 保存先が削除または破損していないか確認し、必要なら空の索引を生成する。
## 再生成した場合は、呼び出し側が全シーンを走査できるよう true を返す。
func ensure_available() -> bool:
	if _load_index():
		return false

	_generate_empty_index("Scope index was deleted or could not be loaded; rebuilding it: %s" % _path)
	return true


func save() -> Error:
	var directory_path := _path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory_path)
	)
	if directory_error != OK:
		return directory_error
	return ResourceSaver.save(_index, _path)


func _load_or_generate() -> void:
	if _load_index():
		return

	var reason := "Scope index does not exist; generating it"
	if FileAccess.file_exists(_path):
		reason = "Scope index could not be loaded; replacing the damaged index"
	_generate_empty_index("%s: %s" % [reason, _path])


func _load_index() -> bool:
	if not FileAccess.file_exists(_path):
		return false

	var loaded := ResourceLoader.load(_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or loaded.get_script() != ScopeIndex:
		return false

	_index.scope_snapshots.assign(loaded.scope_snapshots)
	needs_rebuild = false
	return true


func _generate_empty_index(diagnostic: String) -> void:
	_index.scope_snapshots.clear()
	needs_rebuild = true
	push_warning(diagnostic)
	var error := save()
	if error != OK:
		push_warning(
			"Failed to generate scope index at %s: %s. Editor suggestions remain available in memory."
			% [_path, error_string(error)]
		)
