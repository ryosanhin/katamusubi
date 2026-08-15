@tool
extends Resource

@export var _container_list: Array[ContainerScopeProperty] = []


## コンテナスコープUIDの一覧を取得
func get_scope_uids() -> Array[StringName]:
	return _get_current_uid_list()


## コンテナスコープの名前とコンテナスコープUIDのセットを取得
func get_uid_pairs() -> Dictionary[StringName, StringName]:
	var dict: Dictionary[StringName, StringName] = {}
	for container in _container_list:
		dict[container.scope_id] = container.scope_uid
	return dict


## コンテナスコープUIDからコンテナスコープのプロパティを取得
func get_container_scope_property_with_scope_uid(
	scope_uid: StringName
) -> ContainerScopeProperty:
	if scope_uid.is_empty():
		return null

	for prop in _container_list:
		if prop.scope_uid == scope_uid:
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


## 新規コンテナスコープUIDを取得
func get_new_uid() -> StringName:
	var current_uid_list := _get_current_uid_list()

	var uid := RandomID.get_random_id()
	var loop_count := 0
	const MAX_LOOP_COUNT := 100

	while current_uid_list.has(uid):
		uid = RandomID.get_random_id()
		loop_count += 1
		if loop_count > MAX_LOOP_COUNT:
			push_error("uid生成ループ回数が上限に達しました。")
			return &""

	return uid


## コンテナスコープUIDの一覧を生成
func _get_current_uid_list() -> Array[StringName]:
	var current_uid_list: Array[StringName] = []
	var tmp_list := _container_list.map(
			func(prop: ContainerScopeProperty) -> StringName: return prop.scope_uid
	)
	current_uid_list.assign(tmp_list)
	return current_uid_list
