@tool
extends Resource

@export var _container_list: Array[ContainerScopeProperty] = []


## コンテナスコープUIDの一覧を取得
func get_scope_ids() -> Array[StringName]:
	return _get_current_id_list()


## コンテナスコープの名前とスコープIDのセットを取得
func get_id_pairs() -> Dictionary[StringName, StringName]:
	var dict: Dictionary[StringName, StringName] = {}
	for container in _container_list:
		dict[container.scope_name] = container.scope_id
	return dict


## スコープIDからコンテナスコープのプロパティを取得
func get_container_scope_property_with_scope_id(
	scope_id: StringName
) -> ContainerScopeProperty:
	if scope_id.is_empty():
		return null

	for prop in _container_list:
		if prop.scope_id == scope_id:
			return prop
	
	return null

func add_container(
	prop: ContainerScopeProperty
) -> void:
	_container_list.append(prop)


## 登録されているコンテナスコープリストから削除する[br]
## 削除するコンテナスコープのプロパティ
func remove_container(
	prop: ContainerScopeProperty
) -> void:
	_container_list.erase(prop)


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
	var tmp_list := _container_list.map(
			func(prop: ContainerScopeProperty) -> StringName: return prop.scope_id
	)
	current_id_list.assign(tmp_list)
	return current_id_list
