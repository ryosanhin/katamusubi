@tool
extends RefCounted

const SceneSnapshot := preload("scene_snapshot.gd")
const ScannedEntry := preload("scanned_entry.gd")
const ScopeDiff := preload("scope_diff.gd")

var analyzed_scene_uid: StringName:
	get:
		return _snapshot.scene_uid

var _snapshot: SceneSnapshot
var _comparable_snapshots: Array[ScopeDefinition]

## コンストラクタ[br]
## [param init_snapshot]: シーンのスナップショット
## [param init_comparable_snapshots]: 比較するスコープ定義。
## コンストラクタ内でスキャンされたシーンUIDでフィルタリングするため全定義を引数としても問題ない。[br]
func _init(
	init_snapshot: SceneSnapshot,
	init_comparable_snapshots: Array[ScopeDefinition],
) -> void:
	_snapshot = init_snapshot

	# まとめて渡されるスコープ定義の内、シーンUIDが一致して比較できるものだけを取り出す
	_comparable_snapshots = init_comparable_snapshots.filter(
			func(def: ScopeDefinition) -> bool:
				return def.scene_uid == init_snapshot.scene_uid
	)


## シーンに実在するIDと保存済み定義のIDとの差分を返す。
func get_diff() -> ScopeDiff:
	var existing_scope_ids := _snapshot.get_existing_scope_ids()
	var removed: Array[StringName] = []
	var retained: Array[StringName] =[]
	var added: Array[StringName] = []
	
	for snapshot in _comparable_snapshots:
		if snapshot.scope_id in existing_scope_ids:
			retained.append(snapshot.scope_id)
		else:
			removed.append(snapshot.scope_id)

	for scope_id in existing_scope_ids:
		if not scope_id in retained and not scope_id in added:
			added.append(scope_id)

	return ScopeDiff.new(removed, retained, added)



## 保存済み定義に対応するノードが実行可能な状態かを検査する。
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var scene_path := ResourceUID.uid_to_path(analyzed_scene_uid)

	for snapshot in _comparable_snapshots:
		var matched_entries: Array[ScannedEntry] = []
		for entry in _snapshot.entries:
			if entry.scope_id == snapshot.scope_id:
				matched_entries.append(entry)

		if matched_entries.is_empty():
			errors.append(
				"シーン %s にスコープID '%s' が見つかりませんでした。"
				% [
					scene_path, snapshot.scope_id,
				]
			)
			continue
		if matched_entries.size() > 1:
			errors.append(
					"シーン %s でスコープID '%s' が複数ノードに存在します"
					% [
						scene_path, snapshot.scope_id,
					]
			)
			continue

		var entry := matched_entries[0]
		if not entry.has_script:
			errors.append(
					"シーン %s のノード %s (スコープID '%s') にスクリプトが設定されていません。"
					% [
						scene_path, entry.node_path, snapshot.scope_id,
					]
			)
			continue
		if not entry.inherits_container_scope:
			errors.append(
					"シーン %s のノード %s (スコープID '%s') は ContainerScope を継承していません。"
					% [
						scene_path, entry.node_path, snapshot.scope_id,
					]
			)

	return errors
