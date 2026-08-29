@tool
extends Resource

## 保存済みシーンに含まれるスコープを検索するためのインデックス。
## 正本は保存済みシーン内の[ContainerScope]であり、このリソースは再生成可能。

@export_file var save_path: String
@export var scope_definitions: Array[ScopeDefinition] = []

const RollbackAction := preload("utility/rollback_action.gd")


## 対象シーンの読み取り用スナップショットを一括で置き換える。[br]
## IDの重複などがある場合は何も変更せず、失敗したロールバック操作を返す。[br]
## 成功時に返す操作は、置換前の定義の複製を使って状態を完全に復元する。
func replace_scene_definitions(
	scene_uid: StringName,
	definitions: Array[ScopeDefinition],
) -> RollbackAction:
	var replacements: Array[ScopeDefinition] = []
	var used_ids: Dictionary[StringName, bool] = {}

	for definition in scope_definitions:
		if definition.scene_uid == scene_uid:
			continue
		used_ids[definition.scope_id] = true

	for definition in definitions:
		if definition.scene_uid != scene_uid:
			push_error("異なるシーンのスコープ定義は登録できません: %s" % definition)
			return RollbackAction.new(false, Callable())
		if definition.scope_id.is_empty():
			push_error("空のスコープIDでは登録できません: %s" % definition)
			return RollbackAction.new(false, Callable())
		if used_ids.has(definition.scope_id):
			push_error("既にスコープIDが登録されています: %s" % definition)
			return RollbackAction.new(false, Callable())
		used_ids[definition.scope_id] = true
		replacements.append(_duplicate_definition(definition))

	var original_definitions := _duplicate_definitions(scope_definitions)
	var retained_definitions: Array[ScopeDefinition] = []
	for definition in scope_definitions:
		if definition.scene_uid != scene_uid:
			retained_definitions.append(definition)
	scope_definitions.assign(retained_definitions)
	scope_definitions.append_array(replacements)

	return RollbackAction.new(
			true,
			func() -> void: scope_definitions.assign(original_definitions),
	)


func _duplicate_definitions(
	definitions: Array[ScopeDefinition],
) -> Array[ScopeDefinition]:
	var duplicates: Array[ScopeDefinition] = []
	for definition in definitions:
		duplicates.append(_duplicate_definition(definition))
	return duplicates


func _duplicate_definition(definition: ScopeDefinition) -> ScopeDefinition:
	return ScopeDefinition.new(
		definition.scene_uid,
		definition.scope_name,
		definition.scope_id,
		definition.parent_scope_id,
	)


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
