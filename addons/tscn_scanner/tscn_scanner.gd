@tool
extends EditorPlugin

const CONTAINER_LIST := preload("res://addons/tscn_scanner/container_list.tres")

var _container_scope_inspector_plugin: EditorInspectorPlugin

func _build() -> bool:
	var errors: PackedStringArray = []
	for container_property in CONTAINER_LIST.container_list:
		errors.append_array(TscnScanner.scan(container_property))

	print("エラー %d 件：\n%s" % [errors.size(), "\n".join(errors)])
		
	if errors.size() == 0:
		return true

	return false


func _enter_tree() -> void:
	_container_scope_inspector_plugin = preload(
			"res://addons/tscn_scanner/editor/container_scope_inspector_plugin.gd"
	).new()
	
	add_inspector_plugin(_container_scope_inspector_plugin)


func _exit_tree() -> void:
	if _container_scope_inspector_plugin == null:
		return
	
	remove_inspector_plugin(_container_scope_inspector_plugin)
	_container_scope_inspector_plugin = null
