@tool
extends Resource

@export var scope_snapshots: Array[ScopeSnapshot] = []


## 各シーン毎にインデックスは毎回置き換える。[br]
## 削除したいときは空のスナップショットで置き換える。
func replace_scene_snapshots(scene_uid: StringName, snapshots: Array[ScopeSnapshot]) -> bool:
	for snapshot in snapshots:
		if snapshot.scene_uid != scene_uid or snapshot.scope_id.is_empty():
			push_error("Invalid public scope candidate: %s" % snapshot)
			return false
	
	# 他のシーンのスナップショットは外に避けておく
	var other_scene_snapshots: Array[ScopeSnapshot] = []
	for snapshot in scope_snapshots:
		if snapshot.scene_uid != scene_uid:
			other_scene_snapshots.append(snapshot)
	
	scope_snapshots.assign(other_scene_snapshots)
	scope_snapshots.append_array(snapshots)
	
	return true


func find_by_id(scope_id: StringName) -> Array[ScopeSnapshot]:
	var matches: Array[ScopeSnapshot] = []
	if scope_id.is_empty():
		return matches
	for snapshot in scope_snapshots:
		if snapshot.scope_id == scope_id:
			matches.append(snapshot)
	return matches


func has_duplicate(
	scope_id: StringName,
	excluded_scene_uid: StringName,
	excluded_node_path: NodePath,
) -> bool:
	if scope_id.is_empty():
		return false
	for snapshot in scope_snapshots:
		if snapshot.scope_id != scope_id:
			continue
		if (
			snapshot.scene_uid == excluded_scene_uid
			and snapshot.node_path == excluded_node_path
		):
			continue
		return true
	return false


func save() -> Error:
	if resource_path.is_empty():
		return ERR_FILE_BAD_PATH
	
	return ResourceSaver.save(self, resource_path)
