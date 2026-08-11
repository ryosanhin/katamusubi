@tool
extends Resource
class_name ContainerScopeProperty

@export_file("*.tscn") var _scene_uid: String
var scene_uid: String:
	get:
		return _scene_uid

@export var _node_path: NodePath
var node_path: NodePath:
	get:
		return _node_path

@export var _parent_scope_id: StringName
var parent_scope_id: StringName:
	get:
		return _parent_scope_id

@export var _scope_uid: StringName
var scope_uid: StringName:
	get:
		return _scope_uid
