@tool
extends RefCounted

const ScannedEntry := preload("scanned_entry.gd")

var scene_uid: StringName
var entries: Array[ScannedEntry] = []


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


## スコープIDをキーとして該当するシーン内のスキャンした情報を返す。[br]
## 該当情報が無い場合は[code]null[/code]を返す。
func get_entry(scope_id: StringName) -> ScannedEntry:
	for entry in entries:
		if entry.scope_id == scope_id:
			return entry
	return null
