@tool
extends RefCounted

const SceneSnapshot := preload("scene_snapshot.gd")
const ScannedEntry := preload("scanned_entry.gd")

var analyzed_scene_uid: StringName:
	get:
		return _snapshot.scene_uid

var _snapshot: SceneSnapshot
var _comparable_snapshots: Array[ScopeSnapshot]

## コンストラクタ[br]
## [param init_snapshot]: シーンのスナップショット
## [param init_comparable_snapshots]: 比較するスコープ定義。
## コンストラクタ内でスキャンされたシーンUIDでフィルタリングするため全定義を引数としても問題ない。[br]
func _init(
	init_snapshot: SceneSnapshot,
	init_comparable_snapshots: Array[ScopeSnapshot],
) -> void:
	_snapshot = init_snapshot

	# まとめて渡されるスコープ定義の内、シーンUIDが一致して比較できるものだけを取り出す
	_comparable_snapshots = init_comparable_snapshots.filter(
			func(def: ScopeSnapshot) -> bool:
				return def.scene_uid == init_snapshot.scene_uid
	)


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
