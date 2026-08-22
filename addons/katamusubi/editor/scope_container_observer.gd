@tool
extends RefCounted

const RandomId := preload("random_id.gd")
const ScopeDefinitionList := preload("../runtime/scope_definition_list.gd")
const TscnScanner := preload("tscn_scanner.gd")
const SceneSnapshotAnalyzer := preload("scene_snapshot_analyzer.gd")

var _definition_list: ScopeDefinitionList


func _init(
	init_definition_list: ScopeDefinitionList
) -> void:
	_definition_list = init_definition_list


func on_node_added(node: Node) -> void:
	if EditorInterface.is_playing_scene():
		return

	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null or not _is_node_editable_in_scene(node, scene_root):
		return

	var scope := node as ContainerScope
	if scope == null:
		return
	var is_modified := false

	var is_in_group := scope.is_in_group(scope.CONTAINER_GROUP)

	if not is_in_group:
		scope.add_to_group(scope.CONTAINER_GROUP, true)
		is_modified = true
	
	if scope.scope_id.is_empty():
		var new_id := _get_new_id()
		if new_id.is_empty():
			push_error("新規IDが取得できませんでした。")
		else:
			scope.scope_id = new_id
			is_modified = true
	
	if is_modified:
		EditorInterface.mark_scene_as_unsaved()


func _is_node_editable_in_scene(node: Node, scene_root: Node) -> bool:
	if node == scene_root:
		return true
	if not scene_root.is_ancestor_of(node):
		return false

	var owner := node.owner
	if owner == null:
		return false

	while owner != scene_root:
		if not scene_root.is_ancestor_of(owner):
			return false
		if owner.scene_file_path.is_empty():
			return false
		var instance_owner := owner.owner
		if instance_owner == null:
			return false
		if not instance_owner.is_editable_instance(owner):
			return false
		owner = instance_owner

	return true


func on_filesystem_changed() -> void:
	for definition in _definition_list.scope_definitions:
		var path := ResourceUID.uid_to_path(definition.scene_uid)

		# 削除されていた場合
		if not FileAccess.file_exists(path):
			_definition_list.remove_scope_definition(definition.scope_id)


func on_scene_saved(path: String) -> void:
	var scene_uid := ResourceUID.path_to_uid(path)
	if scene_uid == path:
		push_error("保存先のシーンのUIDが取得できませんでした。")
		return
	var scanner := TscnScanner.new()
	var snapshot := scanner.scan(scene_uid)
	var analyzer := SceneSnapshotAnalyzer.new(snapshot, _definition_list.scope_definitions)
	var diff := analyzer.get_diff()
	var rollback_actions: Array[RollbackAction] = []
	
	for removed_id in diff.removed:
		rollback_actions.append(_definition_list.remove_scope_definition(removed_id))
	
	if rollback_actions.size() == 0:
		return
	
	if not _try_save_definition_list():
		for rollback_action in rollback_actions:
			if not rollback_action.operation_succeeded:
				continue
			rollback_action.rollback()


## 新規スコープIDを取得[br]
## 100回生成して新規IDが生成できなかった場合は[code]&""[/code]を返す
func _get_new_id() -> StringName:
	var current_id_list := _definition_list.get_current_id_list()

	var id := RandomID.get_random_id()
	var loop_count := 1
	const MAX_LOOP_COUNT := 100

	while current_id_list.has(id):
		if loop_count >= MAX_LOOP_COUNT:
			push_error("uid生成ループ回数が上限に達しました。")
			return &""
		id = RandomID.get_random_id()
		loop_count += 1

	return id


func _try_save_definition_list() -> bool:
	var error := _save_definition_list()
	if error != OK:
		push_error("failed save list: %s" % error_string(error))
		return false
	print("successfully saved list")
	return true


func _save_definition_list() -> Error:
	return _definition_list.save()
