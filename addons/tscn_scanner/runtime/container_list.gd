@tool
extends Resource

@export var _container_list: Array[ContainerScopeProperty] = []

func get_new_uid(length: int) -> StringName:
	var current_uid_list: Array[StringName] = []
	var tmp_list := _container_list.map(
		func(prop: ContainerScopeProperty) -> StringName:
			return prop.scope_uid
	)
	current_uid_list.assign(tmp_list)

	var uid := RandomID.get_random_id(length)
	var loop_count := 0
	const MAX_LOOP_COUNT := 100

	while current_uid_list.has(uid):
		uid = RandomID.get_random_id(length)
		loop_count += 1
		if loop_count > MAX_LOOP_COUNT:
			push_error("uid生成ループ回数が上限に達しました。")
			break

	return uid