@tool
extends EditorPlugin

const ScopeIndex := preload("editor/scope_index.gd")
const ContainerScopeObserver := preload("editor/inspector/container_scope_observer.gd")
const ContainerScopeInspectorPlugin := preload("editor/inspector/container_scope_inspector_plugin.gd")

const REBUILD_MENU_NAME := "katamusubi: 公開スコープ索引を再構築"

var _inspector: EditorInspectorPlugin
var _observer: ContainerScopeObserver


func _enter_tree() -> void:
	# ObserverとInspectorで、メモリ上の同じインデックスを共有する。
	var index := ScopeIndex.new()

	_inspector = ContainerScopeInspectorPlugin.new(index)
	add_inspector_plugin(_inspector)

	_observer = ContainerScopeObserver.new(index)
	scene_saved.connect(_observer.update_scene_index)

	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.filesystem_changed.connect(_observer.synchronize_index_with_filesystem)

	add_tool_menu_item(REBUILD_MENU_NAME, _observer.rebuild_all_index)

	# 初期化後に、保存済みシーンから候補を構築する。
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
	
	_inspector = null
	_observer = null


func _refresh_index() -> void:
	# 遅延実行前にプラグインが無効化された場合。
	if not is_inside_tree() or _observer == null:
		return

	_observer.rebuild_all_index()
