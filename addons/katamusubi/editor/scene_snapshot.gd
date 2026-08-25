@tool
extends RefCounted

const ScannedEntry := preload("scanned_entry.gd")

var scene_uid: StringName
var entries: Array[ScannedEntry] = []


func _init(
	init_entries: Array[ScannedEntry]
) -> void:
	if init_entries.size() < 1:
		return
	entries = init_entries
	scene_uid = entries[0].scene_uid
	
	var errors: PackedStringArray = []
	
	for entry in entries:
		if entry.scene_uid != scene_uid:
			errors.append(
					"シーン %s の スキャン結果にシーン %s のスコープ %s （%s）が混在しています。"
					% [
						ResourceUID.uid_to_path(scene_uid),
						ResourceUID.uid_to_path(entry.scene_uid),
						entry.scope_name,
						entry.node_path,
					]
			)
	
	if errors.size() > 0:
		push_error("\n".join(errors))


## シーン内に含まれるスコープID群を返す
func get_existing_scope_ids() -> Array[StringName]:
	var scope_ids: Array[StringName] = []
	for entry in entries:
		if entry.scene_uid == scene_uid:
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
