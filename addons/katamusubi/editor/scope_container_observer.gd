@tool
extends RefCounted

const DEFINITION_LIST := preload("res://addons/katamusubi/scope_definition_list.tres")


func node_added(node: Node) -> void:
	var scope := node as ContainerScope
	if scope == null:
		return

	if scope.scope_id.is_empty():
		var new_id := DEFINITION_LIST.get_new_id()
		if new_id.is_empty():
			push_error("新規IDが取得できませんでした。")
			return
		scope.scope_id = new_id
		EditorInterface.mark_scene_as_unsaved()


func on_filesystem_changed() -> void:
	for definition in DEFINITION_LIST.scope_definitions:
		var path := ResourceUID.uid_to_path(definition.scene_uid)

		# 削除されていた場合
		if not FileAccess.file_exists(path):
			DEFINITION_LIST.remove_scope_definition(definition.scope_id)


func on_scene_saved(path: String) -> void:
	var scene_uid := ResourceUID.path_to_uid(path)
	if scene_uid == path:
		push_error("保存先のシーンのUIDが取得できませんでした。")
		return
	# TODO シーンの変更保存時にそのシーンのスコープを検査する
