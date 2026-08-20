@tool
extends Resource

## スコープのノードが存在するシーンのuid
@export var scene_uid: StringName

## スコープのノードの名前
@export var scope_name: StringName

## スコープのID
@export var scope_id: StringName

## 親スコープのID
@export var parent_scope_id: StringName

## スコープ定義を作成[br]
## [param init_scene_uid]: スコープのノードが存在するシーンのuid[br]
## [param init_scope_name]: スコープのノードの名前[br]
## [param init_scope_id]: スコープのID[br]
## [param init_parent_scope_id]: 親スコープのID
static func create_new_definition(
	init_scene_uid: String,
	init_scope_name: StringName,
	init_scope_id: StringName,
	init_parent_scope_id: StringName,
) -> Resource:
	var definition := new()
	definition.scene_uid = init_scene_uid
	definition.scope_name = init_scope_name
	definition.scope_id = init_scope_id
	definition.parent_scope_id = init_parent_scope_id
	return definition

func _to_string() -> String:
	var path := ResourceUID.uid_to_path(scene_uid)
	return """
		scene_uid: %s
		scope_name: %s
		scope_id: %s
		parent_scope_id: %s
	""" % [
		path,
		scope_name,
		scope_id,
		parent_scope_id,
	]
