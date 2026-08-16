@tool
extends Resource

@export var scope_definitions: Array[ScopeDefinition] = []


## スコーププロパティを追加
func add_container(
	definition: ScopeDefinition
) -> void:
	scope_definitions.append(definition)


## 登録されているスコープリストから削除する[br]
## 削除するスコープのプロパティ
func remove_container(
	definition: ScopeDefinition
) -> void:
	scope_definitions.erase(definition)


## 新規スコープIDを取得
func get_new_id() -> StringName:
	var current_id_list := _get_current_id_list()

	var id := RandomID.get_random_id()
	var loop_count := 0
	const MAX_LOOP_COUNT := 100

	while current_id_list.has(id):
		id = RandomID.get_random_id()
		loop_count += 1
		if loop_count > MAX_LOOP_COUNT:
			push_error("uid生成ループ回数が上限に達しました。")
			return &""

	return id


## スコープIDの一覧を生成
func _get_current_id_list() -> Array[StringName]:
	var current_id_list: Array[StringName] = []
	var tmp_list := scope_definitions.map(
			func(definition: ScopeDefinition) -> StringName: return definition.scope_id
	)
	current_id_list.assign(tmp_list)
	return current_id_list


## スコープIDから該当するスコープ定義を取得[br]
## 存在しない場合は[code]null[/code]を返す
func get_scope_definition(id: StringName) -> ScopeDefinition:
	for definition in scope_definitions:
		if definition.scope_id == id:
			return definition
	return null