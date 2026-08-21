@tool
extends EditorPlugin

const DEFINITION_LIST := preload("res://addons/katamusubi/scope_definition_list.tres")

var _container_scope_inspector_plugin: EditorInspectorPlugin

func _build() -> bool:
	var errors: PackedStringArray = []
	# シーンUIDごとに所属スコープ定義をまとめる
	# Array は Array[ScopeDefinition]
	var definitions_by_scene: Dictionary[StringName, Array] = {}
	for definition in DEFINITION_LIST.scope_definitions:
		if not definitions_by_scene.has(definition.scene_uid):
			definitions_by_scene[definition.scene_uid] = []
		definitions_by_scene[definition.scene_uid].append(definition)

	for scene_uid in definitions_by_scene:
		var definitions: Array[ScopeDefinition] = []
		definitions.assign(definitions_by_scene[scene_uid])
		errors.append_array(TscnScanner.static_scan(scene_uid, definitions))

	print("エラー %d 件：\n%s" % [errors.size(), "\n".join(errors)])
		
	if errors.size() == 0:
		return true

	return false


func _enter_tree() -> void:
	_container_scope_inspector_plugin = preload(
			"res://addons/katamusubi/editor/container_scope_inspector_plugin.gd"
	).new()
	
	add_inspector_plugin(_container_scope_inspector_plugin)


func _exit_tree() -> void:
	if _container_scope_inspector_plugin == null:
		return
	
	remove_inspector_plugin(_container_scope_inspector_plugin)
	_container_scope_inspector_plugin = null
