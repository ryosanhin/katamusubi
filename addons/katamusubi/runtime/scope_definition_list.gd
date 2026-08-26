@tool
extends Resource

@export_file var save_path: String
@export var scope_definitions: Array[ScopeDefinition] = []


## スコープ定義を追加[br]
## [param definition]: 追加するスコープ定義[br]
## returns: ロールバック用クラス
func add_scope_definition(
	definition: ScopeDefinition
) -> RollbackAction:
	if definition.scope_id.is_empty():
		push_error("空のスコープIDでは登録できません: %s" % definition)
		return RollbackAction.new(false, Callable())
	
	# existing_scope_definition が null じゃなかったら既にスコープIDが使われているので無効
	var existing_scope_definition := get_scope_definition(definition.scope_id)
	if existing_scope_definition != null:
		push_error("既にスコープIDが登録されています: %s" % definition)
		return RollbackAction.new(false, Callable())

	scope_definitions.append(definition)
	
	return RollbackAction.new(
			true,
			Callable(
		func() -> void:
			scope_definitions.erase(definition)
			),
	)


## スコープ定義を更新[br]
## [param scope_id]: 変更対象のスコープID[br]
## [param new_scene_uid]: 新しいシーンUID[br]
## [param new_scope_name]: 新しいスコープ名[br]
## [param new_parent_scope_id]: 新しい親スコープID[br]
## returns: ロールバック用クラス
func update_scope_definition(
	scope_id: StringName,
	new_scene_uid: StringName,
	new_scope_name: StringName,
	new_parent_scope_id: StringName,
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
	definition.parent_scope_id = new_parent_scope_id

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
## [param scope_id]: 削除対象のスコープID[br]
## returns: ロールバック用クラス
func remove_scope_definition(
	scope_id: StringName
) -> RollbackAction:
	var definition := get_scope_definition(scope_id)

	if definition == null:
		push_error("対象のスコープ定義が登録されていません: %s" % scope_id)
		return RollbackAction.new(false, Callable())

	var original_index := scope_definitions.find(definition)
	if original_index < 0:
		push_error("対象のスコープ定義が一覧に存在しません: %s" % definition.scope_id)
		return RollbackAction.new(false, Callable())
	
	scope_definitions.erase(definition)

	# 削除されたスコープのIDを親スコープとして
	# 参照しているスコープがあれば参照を解除
	var modified_definitions: Array[ScopeDefinition] = []
	for def in scope_definitions:
		if def.parent_scope_id == scope_id:
			def.parent_scope_id = &""
			modified_definitions.append(def)
	
	return RollbackAction.new(
			true,
			Callable(
		func() -> void:
			scope_definitions.insert(original_index, definition)
			for def in modified_definitions:
				def.parent_scope_id = definition.scope_id
			),
	)


## 新規スコープIDを取得[br]
## 100回生成して新規IDが生成できなかった場合は[code]&""[/code]を返す
func get_new_id() -> StringName:
	var current_id_list := get_current_id_list()

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
func get_current_id_list() -> Array[StringName]:
	var current_id_list: Array[StringName] = []
	var tmp_list := scope_definitions.map(
			func(definition: ScopeDefinition) -> StringName: return definition.scope_id
	)
	current_id_list.assign(tmp_list)
	return current_id_list


## スコープIDから該当するスコープ定義を取得[br]
## 存在しない場合は[code]null[/code]を返す
func get_scope_definition(scope_id: StringName) -> ScopeDefinition:
	for definition in scope_definitions:
		if definition.scope_id == scope_id:
			return definition
	return null

func save() -> Error:
	var path := ResourceUID.uid_to_path(save_path)
	if path.is_empty():
		return Error.FAILED
	return ResourceSaver.save(self, path)
