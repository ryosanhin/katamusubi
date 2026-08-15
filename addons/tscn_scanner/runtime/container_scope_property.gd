@tool
extends Resource
class_name ContainerScopeProperty

@export_file("*.tscn") var scene_uid: String

@export var node_path: NodePath

@export var scope_id: StringName

@export var parent_scope_id: StringName

@export var scope_uid: StringName

static func create_new_property(
	init_scene_uid: String,
	init_node_path: NodePath,
	init_scope_id: StringName,
	init_parent_scope_id: StringName,
	init_scope_uid: StringName,
) -> ContainerScopeProperty:
	var property := ContainerScopeProperty.new()
	property.scene_uid = init_scene_uid
	property.node_path = init_node_path
	property.scope_id = init_scope_id
	property.parent_scope_id = init_parent_scope_id
	property.scope_uid = init_scope_uid
	return property