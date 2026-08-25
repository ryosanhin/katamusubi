@tool
extends RefCounted

const Const := preload("../runtime/plugin_const.gd")
const SceneSnapshot := preload("scene_snapshot.gd")
const ScannedEntry := preload("scanned_entry.gd")

## シーンファイルを走査し、ファイルから読み取れるスコープの情報を返す。
## シーンUIDが無効なときは[code]null[/code]を返す。
static func scan(scene_uid: StringName) -> SceneSnapshot:
	const SCOPE_ID_STRING_NAME := &"scope_id"
	const PARENT_SCOPE_ID_STRING_NAME := &"parent_scope_id"
	const SCRIPT_STRING_NAME := &"script"

	var entries: Array[ScannedEntry] = []
	var packed_scene := load(scene_uid) as PackedScene

	if packed_scene == null:
		push_error("シーン %s が存在しません。" % scene_uid)
		return null

	var scene_state := packed_scene.get_state()
	for node_index in scene_state.get_node_count():
		if not Const.GROUP_NAME in scene_state.get_node_groups(node_index):
			continue

		var scope_id := &""
		var parent_scope_id := &""
		var script: Script = null

		for prop_index in scene_state.get_node_property_count(node_index):
			var property_name := scene_state.get_node_property_name(
					node_index,
					prop_index,
			)
			match property_name:
				SCOPE_ID_STRING_NAME:
					scope_id = scene_state.get_node_property_value(
							node_index,
							prop_index,
					) as StringName
				PARENT_SCOPE_ID_STRING_NAME:
					parent_scope_id = scene_state.get_node_property_value(
							node_index,
							prop_index,
					) as StringName
				SCRIPT_STRING_NAME:
					script = scene_state.get_node_property_value(
							node_index,
							prop_index,
					) as Script

		if scope_id.is_empty():
			continue

		entries.append(ScannedEntry.new(
			scene_uid,
			scene_state.get_node_name(node_index),
			scope_id,
			parent_scope_id,
			scene_state.get_node_path(node_index),
			script != null,
			_inherits_container_scope(script),
		))

	return SceneSnapshot.new(entries)


static func _inherits_container_scope(script: Script) -> bool:
	while script != null:
		if script == ContainerScope:
			return true
		script = script.get_base_script()
	return false
