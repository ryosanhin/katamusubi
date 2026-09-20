@tool
extends EditorPlugin

const SCOPE_INDEX := preload("res://addons/katamusubi/scope_index.tres")
const ContainerScopeObserver := preload("editor/container_scope_observer.gd")
var _inspector: EditorInspectorPlugin
var _observer: ContainerScopeObserver


func _enter_tree() -> void:
	_inspector = preload("res://addons/katamusubi/editor/container_scope_inspector_plugin.gd").new()
	add_inspector_plugin(_inspector)
	_observer = ContainerScopeObserver.new(SCOPE_INDEX)
	scene_saved.connect(_observer.on_scene_saved)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_observer.on_filesystem_changed)
	add_tool_menu_item("Katamusubi: 公開スコープ索引を再構築", _observer.rescan_all_scenes)


func _exit_tree() -> void:
	remove_tool_menu_item("Katamusubi: 公開スコープ索引を再構築")
	if _inspector != null:
		remove_inspector_plugin(_inspector)
	if _observer != null:
		if scene_saved.is_connected(_observer.on_scene_saved):
			scene_saved.disconnect(_observer.on_scene_saved)
		var filesystem := EditorInterface.get_resource_filesystem()
		if filesystem.filesystem_changed.is_connected(_observer.on_filesystem_changed):
			filesystem.filesystem_changed.disconnect(_observer.on_filesystem_changed)
	_inspector = null
	_observer = null
