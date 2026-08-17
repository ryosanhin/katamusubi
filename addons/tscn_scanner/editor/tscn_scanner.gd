@tool
extends RefCounted
class_name TscnScanner

## 一つのシーンを走査し、同シーンに属するすべてのスコープ定義を確認する
static func scan(
	scene_uid: StringName,
	definitions: Array[ScopeDefinition],
) -> PackedStringArray:
	var errors: PackedStringArray = []
	const SCOPE_ID_STRING_NAME := &"scope_id"
	const SCRIPT_STRING_NAME := &"script"
	var packed_scene := load(scene_uid) as PackedScene
	
	if packed_scene == null:
		errors.append("シーン %s が存在しません。" % _get_scene_path(scene_uid))
		return errors

	var scene_state := packed_scene.get_state()
	var nodes_by_scope_id: Dictionary[StringName, Array] = {}

	# 保存済みプロパティを一度だけ読み、スコープIDからノード情報を引けるようにする。
	for node_index in scene_state.get_node_count():
		var scope_id: StringName = &""
		var script: Script = null
		for prop_index in scene_state.get_node_property_count(node_index):
			var property_name := scene_state.get_node_property_name(node_index, prop_index)
			var property_value := scene_state.get_node_property_value(node_index, prop_index)
			if property_name == SCOPE_ID_STRING_NAME:
				scope_id = property_value as StringName
			elif property_name == SCRIPT_STRING_NAME:
				script = property_value as Script

		if scope_id.is_empty():
			continue
		if not nodes_by_scope_id.has(scope_id):
			nodes_by_scope_id[scope_id] = []
		nodes_by_scope_id[scope_id].append({
			"node_path": scene_state.get_node_path(node_index),
			"script": script,
		})

	var scene_path := _get_scene_path(scene_uid)
	for definition in definitions:
		var matching_nodes: Array = nodes_by_scope_id.get(definition.scope_id, [])
		if matching_nodes.is_empty():
			errors.append("シーン %s にスコープID '%s' が見つかりませんでした。" % [
				scene_path,
				definition.scope_id,
			])
			continue
		if matching_nodes.size() > 1:
			var node_paths: PackedStringArray = []
			for node_data in matching_nodes:
				node_paths.append(str(node_data.node_path))
			errors.append("シーン %s でスコープID '%s' が複数ノードに存在します: %s" % [
				scene_path,
				definition.scope_id,
				", ".join(node_paths),
			])

		for node_data in matching_nodes:
			var script: Script = node_data.script
			if script == null:
				errors.append("%sに適切なスクリプトが見つかりませんでした。" % node_data.node_path)
			elif not check_inheritance(script):
				errors.append("%sは適切なクラスを継承していません。" % node_data.node_path)

	return errors


static func _get_scene_path(scene_uid: StringName) -> String:
	var resource_id := ResourceUID.text_to_id(scene_uid)
	if resource_id == ResourceUID.INVALID_ID:
		return scene_uid
	return ResourceUID.get_id_path(resource_id)

static func check_inheritance(script: Script) -> bool:
	while script != null:
		if script == ContainerScope:
			return true
		script = script.get_base_script()
	return false
