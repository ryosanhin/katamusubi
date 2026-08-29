@tool
extends RefCounted

## 保存済みシーンと現在編集中のシーンから、親スコープ候補を都度合成する。

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")

var _scope_index: ScopeIndex


func _init(init_scope_index: ScopeIndex) -> void:
	_scope_index = init_scope_index


func get_candidates(
	target: ContainerScope,
	scene_root: Node,
) -> Array[ScopeDefinition]:
	var candidates: Array[ScopeDefinition] = []
	if not _is_target_in_edited_scene(target, scene_root):
		return candidates

	var edited_scene_uid := _get_edited_scene_uid(scene_root)
	for snapshot in _scope_index.scope_snapshots:
		if snapshot.scope_id.is_empty():
			continue
		if not edited_scene_uid.is_empty() and snapshot.scene_uid == edited_scene_uid:
			continue
		candidates.append(snapshot)

	for scope in _get_edited_scene_scopes(scene_root):
		if scope.scope_id.is_empty():
			continue
		candidates.append(ScopeDefinition.new(
			edited_scene_uid,
			scope.name,
			scope.scope_id,
			scope.parent_scope_id,
		))

	return candidates


func get_candidate(
	scope_id: StringName,
	target: ContainerScope,
	scene_root: Node,
) -> ScopeDefinition:
	for candidate in get_candidates(target, scene_root):
		if candidate.scope_id == scope_id:
			return candidate
	return null


func _get_edited_scene_scopes(scene_root: Node) -> Array[ContainerScope]:
	var scopes: Array[ContainerScope] = []
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node := stack.pop_back()
		if node == scene_root or node.owner == scene_root:
			var scope := node as ContainerScope
			if scope != null:
				scopes.append(scope)
		for index in range(node.get_child_count() - 1, -1, -1):
			stack.append(node.get_child(index))
	return scopes


func _get_edited_scene_uid(scene_root: Node) -> StringName:
	if scene_root.scene_file_path.is_empty():
		return &""
	var scene_uid := ResourceUID.path_to_uid(scene_root.scene_file_path)
	return &"" if scene_uid == scene_root.scene_file_path else scene_uid


func _is_target_in_edited_scene(target: ContainerScope, scene_root: Node) -> bool:
	if scene_root == null:
		push_error("編集中のシーンがありません。")
		return false
	if target != scene_root and not scene_root.is_ancestor_of(target):
		push_error("コンテナスコープは編集中のシーンに属していません。")
		return false

	return true
