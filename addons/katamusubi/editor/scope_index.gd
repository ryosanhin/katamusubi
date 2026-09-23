@tool
extends Resource

## 保存形式を変更したら、この値を増やす。
const CURRENT_FORMAT_VERSION := 1

## 古いファイルでプロパティが存在しない場合を検出するため、初期値は0。
@export_storage var format_version: int = 0
@export_storage var scope_snapshots: Array[ScopeSnapshot] = []


## 各シーン毎に渡されたスナップショットでインデックスを置き換える。[br]
## 削除したいときは空のスナップショットで置き換える。
func replace_scene_snapshots(scene_uid: StringName, snapshots: Array[ScopeSnapshot]) -> bool:
	for snapshot in snapshots:
		if snapshot.scene_uid != scene_uid or snapshot.scope_id.is_empty():
			push_error("Invalid public scope candidate: %s" % snapshot)
			return false
	
	# -----シーン内に存在するスコープIDの差分を確認-----
	var current_ids: Array[StringName] = []
	var new_ids: Array[StringName] = []
	
	for snapshot in scope_snapshots:
		if snapshot.scene_uid == scene_uid:
			current_ids.append(snapshot.scope_id)
	for snapshot in snapshots:
		new_ids.append(snapshot.scope_id)
	
	# 順番だけが変わっても、候補の変更とはみなさない。
	# 重複の個数は比較対象になる。
	current_ids.sort()
	new_ids.sort()
	if current_ids == new_ids:
		return true
	
	# -----変更があった場合の置き換え処理-----
	# 他のシーンのスナップショットは外に避けておく
	var other_scene_snapshots: Array[ScopeSnapshot] = []
	for snapshot in scope_snapshots:
		if snapshot.scene_uid != scene_uid:
			other_scene_snapshots.append(snapshot)
	
	scope_snapshots.assign(other_scene_snapshots)
	scope_snapshots.append_array(snapshots)
	emit_changed()
	return true
