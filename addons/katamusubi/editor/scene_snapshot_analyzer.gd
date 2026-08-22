@tool
extends RefCounted

const SceneSnapshot := preload("scene_snapshot.gd")
const ScannedEntry := preload("scanned_entry.gd")
const ScopeDiff := preload("scope_diff.gd")

var _snapshot: SceneSnapshot
var _definitions: Array[ScopeDefinition]


func _init(
	init_snapshot: SceneSnapshot,
	init_definitions: Array[ScopeDefinition],
) -> void:
	_snapshot = init_snapshot
	_definitions = init_definitions


## シーンに実在するIDと保存済み定義のIDとの差分を返す。
func get_diff() -> ScopeDiff:
	var existing_scope_ids := _snapshot.get_existing_scope_ids()
	var removed: Array[StringName] = []
	var retained: Array[StringName] =[]
	var added: Array[StringName] = []

	for definition in _definitions:
		if definition.scope_id in existing_scope_ids:
			retained.append(definition.scope_id)
		else:
			removed.append(definition.scope_id)

	for scope_id in existing_scope_ids:
		if not scope_id in retained and not scope_id in added:
			added.append(scope_id)

	return ScopeDiff.new(removed, retained, added)



## 保存済み定義に対応するノードが実行可能な状態かを検査する。
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var scene_path := _get_scene_path()

	for definition in _definitions:
		var matched_entries: Array[ScannedEntry] = []
		for entry in _snapshot.entries:
			if entry.scope_id == definition.scope_id:
				matched_entries.append(entry)

		if matched_entries.is_empty():
			errors.append(
				"シーン %s にスコープID '%s' が見つかりませんでした。"
				% [
					scene_path, definition.scope_id,
				]
			)
			continue
		if matched_entries.size() > 1:
			errors.append(
					"シーン %s でスコープID '%s' が複数ノードに存在します"
					% [
						scene_path, definition.scope_id,
					]
			)
			continue

		var entry := matched_entries[0]
		if not entry.has_script:
			errors.append(
					"シーン %s のノード %s (スコープID '%s') にスクリプトが設定されていません。"
					% [
						scene_path, entry.node_path, definition.scope_id,
					]
			)
			continue
		if not entry.inherits_container_scope:
			errors.append(
					"シーン %s のノード %s (スコープID '%s') は ContainerScope を継承していません。"
					% [
						scene_path, entry.node_path, definition.scope_id,
					]
			)

	return errors


func _get_scene_path() -> String:
	if String(_snapshot.scene_uid).begins_with("uid://"):
		return ResourceUID.uid_to_path(_snapshot.scene_uid)
	return _snapshot.scene_uid
