@tool
extends RefCounted
## 再生成可能なスコープ索引を、アドオン本体とは別の場所に保管する。

const ScopeIndex := preload("scope_index.gd")

const PROJECT_SETTING := "katamusubi/editor/scope_index_path"
const DEFAULT_PATH := "res://.godot/katamusubi/scope_index.tres"

var index: ScopeIndex = ScopeIndex.new()
var path: String
var needs_rebuild := false


func _init(storage_path: String = get_configured_path()) -> void:
	path = storage_path
	_load_or_generate()


static func get_configured_path() -> String:
	return str(ProjectSettings.get_setting(PROJECT_SETTING, DEFAULT_PATH))


static func register_project_setting() -> void:
	if not ProjectSettings.has_setting(PROJECT_SETTING):
		ProjectSettings.set_setting(PROJECT_SETTING, DEFAULT_PATH)
	ProjectSettings.set_initial_value(PROJECT_SETTING, DEFAULT_PATH)
	ProjectSettings.add_property_info({
		"name": PROJECT_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres",
	})


## 保存先が削除または破損していないか確認し、必要なら空の索引を生成する。
## 再生成した場合は、呼び出し側が全シーンを走査できるよう true を返す。
func ensure_available() -> bool:
	if _load_index():
		return false

	_generate_empty_index("Scope index was deleted or could not be loaded; rebuilding it: %s" % path)
	return true


func save() -> Error:
	var directory_path := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory_path)
	)
	if directory_error != OK:
		return directory_error
	return ResourceSaver.save(index, path)


func _load_or_generate() -> void:
	if _load_index():
		return

	var reason := "Scope index does not exist; generating it"
	if FileAccess.file_exists(path):
		reason = "Scope index could not be loaded; replacing the damaged index"
	_generate_empty_index("%s: %s" % [reason, path])


func _load_index() -> bool:
	if not FileAccess.file_exists(path):
		return false

	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or loaded.get_script() != ScopeIndex:
		return false

	index.scope_snapshots.assign(loaded.scope_snapshots)
	needs_rebuild = false
	return true


func _generate_empty_index(diagnostic: String) -> void:
	index.scope_snapshots.clear()
	needs_rebuild = true
	push_warning(diagnostic)
	var error := save()
	if error != OK:
		push_warning(
			"Failed to generate scope index at %s: %s. Editor suggestions remain available in memory."
			% [path, error_string(error)]
		)
