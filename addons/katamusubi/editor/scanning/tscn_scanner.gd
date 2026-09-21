@tool
extends RefCounted

const SceneSnapshot := preload("scene_snapshot.gd")


static func scan(scene_uid: StringName) -> SceneSnapshot:
	var packed_scene := load(scene_uid) as PackedScene
	if packed_scene == null:
		return SceneSnapshot.new(false, scene_uid, [], "Scene could not be loaded: %s" % scene_uid)
	var entries: Array[ScopeSnapshot] = []
	var state := packed_scene.get_state()
	for node_index in state.get_node_count():
		if state.get_node_instance(node_index) != null:
			continue
		
		var script: Script
		var scope_id := &""

		for property_index in state.get_node_property_count(node_index):
			var property_name := state.get_node_property_name(node_index, property_index)
			match property_name:
				&"script":
					script = state.get_node_property_value(node_index, property_index) as Script
				&"scope_id":
					scope_id = state.get_node_property_value(node_index, property_index) as StringName

		if not scope_id.is_empty() and _inherits_container_scope(script):
			entries.append(
				ScopeSnapshot.new(scene_uid, state.get_node_path(node_index), scope_id)
			)

	return SceneSnapshot.new(true, scene_uid, entries)


static func _inherits_container_scope(script: Script) -> bool:
	while script != null:
		if script == ContainerScope:
			return true
		script = script.get_base_script()
	return false
