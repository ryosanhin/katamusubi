@tool
extends Resource
class_name ScopeDefinition

## スコープのノードが存在するシーンのuid
@export var scene_uid: StringName

## スコープのノードのツリーでの場所
@export var node_path: NodePath

## スコープのノードの名前
@export var scope_name: StringName

## スコープのID
@export var scope_id: StringName

## 親スコープのID
@export var parent_scope_id: StringName

## スコープのプロパティを作成[br]
## [param init_scene_uid]: スコープのノードが存在するシーンのuid[br]
## [param init_node_path]: スコープのノードのツリーでの場所[br]
## [param init_scope_name]: スコープのノードの名前[br]
## [param init_scope_id]: スコープのID[br]
## [param init_parent_scope_id]: 親スコープのID
static func create_new_property(
	init_scene_uid: String,
	init_node_path: NodePath,
	init_scope_name: StringName,
	init_scope_id: StringName,
	init_parent_scope_id: StringName,
) -> ScopeDefinition:
	var property := ScopeDefinition.new()
	property.scene_uid = init_scene_uid
	property.node_path = init_node_path
	property.scope_name = init_scope_name
	property.scope_id = init_scope_id
	property.parent_scope_id = init_parent_scope_id
	return property