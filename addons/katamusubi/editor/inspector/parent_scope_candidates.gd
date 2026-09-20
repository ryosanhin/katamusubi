@tool
extends RefCounted

const ScopeIndex := preload("res://addons/katamusubi/editor/scope_index.gd")
var _scope_index: ScopeIndex


func _init(init_scope_index: ScopeIndex) -> void:
	_scope_index = init_scope_index


## Overlays the live edited scene over (and instead of) its saved cache entries.
func get_candidates(target: ContainerScope, scene_root: Node, query := "") -> Array[ScopeSnapshot]:
	var candidates: Array[ScopeSnapshot] = []
	if not _is_target_in_scene(target, scene_root):
		return candidates
	var edited_uid := _edited_scene_uid(scene_root)
	for candidate in _scope_index.scope_snapshots:
		if not edited_uid.is_empty() and candidate.scene_uid == edited_uid:
			continue
		if _matches(candidate.scope_id, query):
			candidates.append(candidate)
	for scope in _edited_scopes(scene_root):
		if scope.scope_id.is_empty() or not _matches(scope.scope_id, query):
			continue
		candidates.append(ScopeSnapshot.new(edited_uid, scene_root.get_path_to(scope), scope.scope_id))
	return candidates


func get_candidates_by_id(scope_id: StringName, target: ContainerScope, scene_root: Node) -> Array[ScopeSnapshot]:
	var matches: Array[ScopeSnapshot] = []
	for candidate in get_candidates(target, scene_root):
		if candidate.scope_id == scope_id:
			matches.append(candidate)
	return matches


func _matches(scope_id: StringName, query: String) -> bool:
	return query.is_empty() or query.to_lower() in String(scope_id).to_lower()


func _edited_scopes(root: Node) -> Array[ContainerScope]:
	var scopes: Array[ContainerScope] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node := stack.pop_back()
		if node == root or node.owner == root:
			if node is ContainerScope:
				scopes.append(node)
			for child in node.get_children():
				stack.append(child)
	return scopes


func _edited_scene_uid(root: Node) -> StringName:
	if root.scene_file_path.is_empty():
		return &""
	var uid := ResourceUID.path_to_uid(root.scene_file_path)
	return &"" if uid == root.scene_file_path else uid


func _is_target_in_scene(target: ContainerScope, root: Node) -> bool:
	return root != null and (target == root or target.owner == root)
