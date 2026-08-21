@tool
extends RefCounted
class_name SceneScopeSnapshot

var scene_uid: StringName
var entries: Array[ScannedEntry] = []

var unique_scope_ids: Array[StringName] = []

func _init(
	init_scene_uid: StringName,
	init_entries: Array[ScannedEntry]
) -> void:
	scene_uid = init_scene_uid
	entries = init_entries


## シーン内に含まれるスコープID群を返す
func get_existing_scope_ids() -> Array[StringName]:
	var scope_ids: Array[StringName] = []
	for entry in entries:
		if entry.scene_uid != scene_uid:
			push_error("異なるシーンUIDに存在するスコープIDが存在します")
			continue
		scope_ids.append(entry.scope_id)
	return scope_ids


## 重複個数を数える。最小値は0（重複無し）
func get_duplicated_count(scope_id: StringName) -> int:
	var count := 0
	for entry in entries:
		if entry.scope_id == scope_id:
			count += 1
	return count
