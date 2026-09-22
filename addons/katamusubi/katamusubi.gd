@tool
extends EditorPlugin

const ContainerScopeObserver := preload("editor/inspector/container_scope_observer.gd")
const ScopeIndexStorage := preload("editor/scope_index_storage.gd")
var _inspector: EditorInspectorPlugin
var _observer: ContainerScopeObserver


func _enter_tree() -> void:
	_observer = ContainerScopeObserver.new(ScopeIndexStorage.PATH)
	_inspector = preload("editor/inspector/container_scope_inspector_plugin.gd").new(
		_observer.get_scope_index()
	)
	add_inspector_plugin(_inspector)

	scene_saved.connect(_observer.update_scene_index)

	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.filesystem_changed.connect(_observer.synchronize_index_with_filesystem)

	add_tool_menu_item("katamusubi: 公開スコープ索引を再構築", _observer.rebuild_all_index)
	_observer.rebuild_index_if_needed.call_deferred()


func _exit_tree() -> void:
	remove_tool_menu_item("katamusubi: 公開スコープ索引を再構築")
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
