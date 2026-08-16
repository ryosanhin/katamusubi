@tool
extends Resource

@export var container_list: Array[ScopeDefinition] = []


## スコーププロパティを追加
func add_container(
	prop: ScopeDefinition
) -> void:
	container_list.append(prop)


## 登録されているスコープリストから削除する[br]
## 削除するスコープのプロパティ
func remove_container(
	prop: ScopeDefinition
) -> void:
	container_list.erase(prop)


## 新規スコープIDを取得
func get_new_id() -> StringName:
	var current_id_list := _get_current_id_list()

	var uid := RandomID.get_random_id()
	var loop_count := 0
	const MAX_LOOP_COUNT := 100

	while current_id_list.has(uid):
		uid = RandomID.get_random_id()
		loop_count += 1
		if loop_count > MAX_LOOP_COUNT:
			push_error("uid生成ループ回数が上限に達しました。")
			return &""

	return uid


## スコープIDの一覧を生成
func _get_current_id_list() -> Array[StringName]:
	var current_id_list: Array[StringName] = []
	var tmp_list := container_list.map(
			func(prop: ScopeDefinition) -> StringName: return prop.scope_id
	)
	current_id_list.assign(tmp_list)
	return current_id_list


## スコープIDから該当するスコーププロパティを取得[br]
## 存在しない場合は[code]null[/code]を返す
func get_scope_property(id: StringName) -> ScopeDefinition:
	for prop in container_list:
		if prop.scope_id == id:
			return prop
	return null