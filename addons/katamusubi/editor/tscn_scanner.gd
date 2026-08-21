@tool
extends RefCounted
class_name TscnScanner

const GROUP_NAME := &"test_group"
const SCOPE_ID_STRING_NAME := &"scope_id"
const SCRIPT_STRING_NAME := &"script"


## シーンファイルを走査し、ファイルから読み取れるスコープの情報を返す。
func scan(scene_uid: StringName) -> SceneScopeSnapshot:
	var entries: Array[ScannedEntry] = []
	var packed_scene := load(scene_uid) as PackedScene

	if packed_scene == null:
		push_error("シーン %s が存在しません。" % scene_uid)
		return null

	var scene_state := packed_scene.get_state()
	for node_index in scene_state.get_node_count():
		if not GROUP_NAME in scene_state.get_node_groups(node_index):
			continue

		var scope_id: StringName = &""
		var script: Script = null
		for prop_index in scene_state.get_node_property_count(node_index):
			var property_name := scene_state.get_node_property_name(
					node_index,
					prop_index,
			)
			if property_name == SCOPE_ID_STRING_NAME:
				scope_id = scene_state.get_node_property_value(
						node_index,
						prop_index,
				) as StringName
			elif property_name == SCRIPT_STRING_NAME:
				script = scene_state.get_node_property_value(
						node_index,
						prop_index,
				) as Script

		if scope_id.is_empty():
			continue

		entries.append(ScannedEntry.new(
			scene_uid,
			scope_id,
			scene_state.get_node_path(node_index),
			script != null,
			_inherits_container_scope(script),
		))

	return SceneScopeSnapshot.new(scene_uid, entries)


func _inherits_container_scope(script: Script) -> bool:
	while script != null:
		if script == ContainerScope:
			return true
		script = script.get_base_script()
	return false
