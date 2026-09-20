@tool
extends Resource
class_name ScopeSnapshot

## A rebuildable description of a public ContainerScope.
@export var scene_uid: StringName
@export var node_path: NodePath
@export var scope_id: StringName


func _init(
	init_scene_uid: StringName = &"",
	init_node_path: NodePath = NodePath(),
	init_scope_id: StringName = &"",
) -> void:
	scene_uid = init_scene_uid
	node_path = init_node_path
	scope_id = init_scope_id


func _to_string() -> String:
	return "scene_uid: %s, node_path: %s, scope_id: %s" % [
		ResourceUID.uid_to_path(scene_uid), node_path, scope_id,
	]
