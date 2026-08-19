@tool
extends Resource

@export var scope_definitions: Array[ScopeDefinition] = []


## スコープ定義を追加
## [param definition]: 追加するスコープ定義
func add_scope_definition(
	definition: ScopeDefinition
) -> RollbackAction:
	if definition.scope_id.is_empty():
		push_error("空のスコープIDでは登録できません: %s" % definition)
		return RollbackAction.new(false, Callable())
	
	scope_definitions.append(definition)
	
	return RollbackAction.new(
			true,
			Callable(
		func() -> void:
			scope_definitions.erase(definition)
			),
	)


## スコープ定義を更新
func update_scope_definition(
	scope_id: StringName,
	new_scene_uid: StringName,
	new_scope_name: StringName,
	parent_scope_id: StringName,
) -> RollbackAction:
	var definition := get_scope_definition(scope_id)
	if definition == null:
		push_error("対象のスコープ定義が登録されていません: %s" % scope_id)
		return RollbackAction.new(false, Callable())
	
	# アップデート処理
	var original_scene_uid := definition.scene_uid
	var original_scope_name := definition.scope_name
	var original_parent_scope_id := definition.parent_scope_id
	# データを新しいものに置き換える
	definition.scene_uid = new_scene_uid
	definition.scope_name = new_scope_name
	definition.parent_scope_id = parent_scope_id

	return RollbackAction.new(
			true,
			Callable(
		func() -> void:
			definition.scene_uid = original_scene_uid
			definition.scope_name = original_scope_name
			definition.parent_scope_id = original_parent_scope_id
			),
	)


## 登録されているスコープ定義リストから削除する[br]
## [param scope_id]: 削除対象のスコープID
func remove_scope_definition(
	scope_id: StringName
) -> RollbackAction:
	var definition := get_scope_definition(scope_id)

	if definition == null:
		push_error("対象のスコープ定義が登録されていません: %s" % scope_id)
		return

	var original_index := scope_definitions.find(definition)
	if original_index < 0:
		push_error("対象のスコープ定義が一覧に存在しません: %s" % definition.scope_id)
		return null
	
	scope_definitions.erase(definition)

	return RollbackAction.new(
			true,
			Callable(
		func() -> void:
			scope_definitions.insert(original_index, definition)
			),
	)


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