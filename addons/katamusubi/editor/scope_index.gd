@tool
extends Resource

## 保存済みシーンに含まれるスコープを検索するためのインデックス。
## 正本は保存済みシーン内の[ContainerScope]であり、このリソースは再生成可能。

@export_file var save_path: String
@export var scope_snapshots: Array[ScopeSnapshot] = []

const RollbackAction := preload("utility/rollback_action.gd")


## 対象シーンの読み取り用スナップショットを一括で置き換える。[br]
## IDの重複などがある場合は何も変更せず、失敗したロールバック操作を返す。[br]
## 成功時に返す操作は、置換前の定義の複製を使って状態を完全に復元する。
func replace_scene_snapshots(
	scene_uid: StringName,
	snapshots: Array[ScopeSnapshot],
) -> RollbackAction:
	var replacements: Array[ScopeSnapshot] = []

	# HashSet<T> 的なものが無いので辞書型で代替
	## 他のシーンで使われているスコープID
	var used_ids_set: Dictionary[StringName, bool] = {}
	
	## 今検査しているシーン内で使われているスコープID
	var new_ids_set: Dictionary[StringName, bool] = {}

	for snapshot in scope_snapshots:
		if snapshot.scene_uid == scene_uid:
			continue
		used_ids_set[snapshot.scope_id] = true

	for snapshot in snapshots:
		if snapshot.scene_uid != scene_uid:
			push_error("異なるシーンのスコープ定義は登録できません: %s" % snapshot)
			return RollbackAction.new(false, Callable())
		if snapshot.scope_id.is_empty():
			push_error("空のスコープIDでは登録できません: %s" % snapshot)
			return RollbackAction.new(false, Callable())
		if snapshot.scope_id in used_ids_set:
			push_error("既にスコープIDが登録されています: %s" % snapshot)
			return RollbackAction.new(false, Callable())
		# 同一シーン内の重複は代表を1件残す。これによりビルド時に対象シーンが
		# 再スキャンされ、SceneSnapshotAnalyzer が実ノードの重複を報告できる。
		if snapshot.scope_id in new_ids_set:
			continue
		new_ids_set[snapshot.scope_id] = true
		replacements.append(_duplicate_snapshot(snapshot))

	var original_snapshots := _duplicate_snapshots(scope_snapshots)
	var retained_snapshots: Array[ScopeSnapshot] = []
	
	for snapshot in scope_snapshots:
		# 変更を適用するシーン以外のデータはそのままコピー
		if snapshot.scene_uid != scene_uid:
			retained_snapshots.append(snapshot)
	
	## TODO: ここassginでディープコピーをする必要ある？
	scope_snapshots.assign(retained_snapshots)
	scope_snapshots.append_array(replacements)

	return RollbackAction.new(
			true,
			func() -> void: scope_snapshots.assign(original_snapshots),
	)


func _duplicate_snapshots(
	snapshots: Array[ScopeSnapshot],
) -> Array[ScopeSnapshot]:
	var duplicates: Array[ScopeSnapshot] = []
	for snapshot in snapshots:
		duplicates.append(_duplicate_snapshot(snapshot))
	return duplicates


func _duplicate_snapshot(snapshot: ScopeSnapshot) -> ScopeSnapshot:
	return snapshot.to_saved_snapshot()


## スコープIDの一覧を生成
func get_current_id_list() -> Array[StringName]:
	var current_id_list: Array[StringName] = []
	var tmp_list := scope_snapshots.map(
			func(snapshot: ScopeSnapshot) -> StringName: return snapshot.scope_id
	)
	current_id_list.assign(tmp_list)
	return current_id_list


## スコープIDから該当するスコープ定義を取得[br]
## 存在しない場合は[code]null[/code]を返す
func get_scope_snapshot(scope_id: StringName) -> ScopeSnapshot:
	for snapshot in scope_snapshots:
		if snapshot.scope_id == scope_id:
			return snapshot
	return null


func save() -> Error:
	var path := ResourceUID.ensure_path(save_path)
	if path.is_empty():
		return Error.FAILED
	return ResourceSaver.save(self, path)
