@tool
extends EditorPlugin

const ScopeIndexStorage := preload("editor/scope_index_storage.gd")
const ContainerScopeObserver := preload("editor/inspector/container_scope_observer.gd")
const ContainerScopeInspectorPlugin := preload("editor/inspector/container_scope_inspector_plugin.gd")

const REBUILD_MENU_NAME := "katamusubi: 公開スコープ索引を再構築"
const CACHE_PATH := "katamusubi/scope_index.tres"

var _storage: ScopeIndexStorage
var _inspector: EditorInspectorPlugin
var _observer: ContainerScopeObserver

var _save_timer: Timer
const SAVE_DELAY := 0.5

func _enter_tree() -> void:
	var cache_path := EditorInterface.get_editor_paths() \
			.get_project_settings_dir() \
			.path_join(CACHE_PATH)
	
	_storage = ScopeIndexStorage.new(cache_path)
	var index := _storage.get_index()

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	add_child(_save_timer)

	_save_timer.timeout.connect(_flush_index)
	_storage.save_requested.connect(_schedule_save)

	_inspector = ContainerScopeInspectorPlugin.new(index)
	add_inspector_plugin(_inspector)

	_observer = ContainerScopeObserver.new(index)
	scene_saved.connect(_observer.update_scene_index)

	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.filesystem_changed.connect(_observer.synchronize_index_with_filesystem)

	add_tool_menu_item(REBUILD_MENU_NAME, _observer.rebuild_all_index)

	# キャッシュが正常でも、終了中のシーン変更を確認する。
	# 初期化が終わってから開始する。
	_refresh_index.call_deferred()


func _exit_tree() -> void:
	remove_tool_menu_item(REBUILD_MENU_NAME)
	if _inspector != null:
		remove_inspector_plugin(_inspector)
	
	if _observer != null:
		if scene_saved.is_connected(_observer.update_scene_index):
			scene_saved.disconnect(_observer.update_scene_index)
		var filesystem := EditorInterface.get_resource_filesystem()
		if filesystem.filesystem_changed.is_connected(_observer.synchronize_index_with_filesystem):
			filesystem.filesystem_changed.disconnect(_observer.synchronize_index_with_filesystem)
	
	if _storage != null:
		if _storage.save_requested.is_connected(_schedule_save):
			_storage.save_requested.disconnect(_schedule_save)

	if _save_timer != null:
		if _save_timer.timeout.is_connected(_flush_index):
			_save_timer.timeout.disconnect(_flush_index)
		_save_timer.stop()

	# 正常終了・無効化時に、保存待ちの変更を反映する。
	if _storage != null:
		_flush_index()

	if _save_timer != null:
		_save_timer.queue_free()
	
	_inspector = null
	_observer = null
	_storage = null
	_save_timer = null


func _flush_index() -> void:
	var error := _storage.save()
	if error != OK:
		push_warning(
			"Failed to save scope index cache: %s"
			% error_string(error)
		)


func _schedule_save() -> void:
	_save_timer.start()


func _refresh_index() -> void:
	# 遅延実行前にプラグインが無効化された場合。
	if not is_inside_tree() or _observer == null:
		return

	_observer.rebuild_all_index()

	# キャッシュが存在せず、再構築結果も空だった場合にも対応。
	if _storage.is_dirty():
		_schedule_save()
