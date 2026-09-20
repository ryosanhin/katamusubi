@tool
extends Resource

@export var scope_snapshots: Array[ScopeSnapshot] = []


## Atomically replaces one scene's entries. Duplicate names are intentionally kept.
func replace_scene_snapshots(scene_uid: StringName, snapshots: Array[ScopeSnapshot]) -> bool:
	for snapshot in snapshots:
		if snapshot.scene_uid != scene_uid or snapshot.scope_id.is_empty():
			push_error("Invalid public scope candidate: %s" % snapshot)
			return false
	var retained: Array[ScopeSnapshot] = []
	for snapshot in scope_snapshots:
		if snapshot.scene_uid != scene_uid:
			retained.append(snapshot)
	scope_snapshots.assign(retained)
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


func save() -> Error:
	if resource_path.is_empty():
		return ERR_FILE_BAD_PATH
	
	return ResourceSaver.save(self, resource_path)
