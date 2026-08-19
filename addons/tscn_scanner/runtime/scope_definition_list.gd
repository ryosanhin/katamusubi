@tool
extends Resource

@export var scope_definitions: Array[ScopeDefinition] = []


## スコープ定義を追加
## [param definition]: 追加するスコープ定義
func add_scope_definitions(
	definition: ScopeDefinition
) -> RollbackAction:
	if definition.scope_id.is_empty():
		push_error("空のスコープIDでは登録できません: %s" % definition)
		return null
	scope_definitions.append(definition)
	return RollbackAction.new(Callable(
			func() -> void:
				scope_definitions.erase(definition)
	))


## 登録されているスコープ定義リストから削除する[br]
## [param definition]: 削除するスコープ定義
func remove_scope_definitions(
	definition: ScopeDefinition
) -> void:
	scope_definitions.erase(definition)


## 新規スコープIDを取得[br]
## 100回生成して新規IDが生成できなかった場合は[code]&""[/code]を返す
func get_new_id() -> StringName:
	var current_id_list := _get_current_id_list()

	var id := RandomID.get_random_id()
	var loop_count := 1
	const MAX_LOOP_COUNT := 100

	while current_id_list.has(id):
		if loop_count >= MAX_LOOP_COUNT:
			push_error("uid生成ループ回数が上限に達しました。")
			return &""
		id = RandomID.get_random_id()
		loop_count += 1

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