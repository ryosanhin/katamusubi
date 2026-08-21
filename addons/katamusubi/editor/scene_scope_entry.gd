@tool
extends RefCounted
class_name ScannedEntry

var scene_uid: StringName
var scope_id: StringName
var node_path: NodePath
var has_script: bool
var inherits_container_scope: bool

func _init(
	init_scene_uid: StringName,
	init_scope_id: StringName,
	init_node_path: NodePath,
	init_has_script: bool,
	init_inherits_container_scope: bool,
) -> void:
	scene_uid = init_scene_uid
	scope_id = init_scope_id
	node_path = init_node_path
	has_script = init_has_script
	inherits_container_scope = init_inherits_container_scope
