@tool
extends RefCounted
class_name TscnScanner

## 一つのシーンを走査し、同シーンに属するすべてのスコープ定義を確認する[br]
## [param scene_uid]: 調べたいシーンのUID[br]
## [param definitions]: そのシーンに所属していると思われるスコープ定義群[br]
## returns: エラー一覧
static func scan(
	scene_uid: StringName,
	definitions: Array[ScopeDefinition],
) -> PackedStringArray:
	var errors: PackedStringArray = []
	const GROUP_NAME := &"test_group"
	const SCOPE_ID_STRING_NAME := &"scope_id"
	const SCRIPT_STRING_NAME := &"script"
	var packed_scene := load(scene_uid) as PackedScene
	
	if packed_scene == null:
		errors.append("シーン %s が存在しません。" % _get_scene_path(scene_uid))
		return errors

	var scene_state := packed_scene.get_state()
	# Arrayの中身はScopeScanResult
	var nodes_by_scope_id: Dictionary[StringName, Array] = {}

	# 保存済みプロパティを一度だけ読み、スコープIDからノード情報を引けるようにする。
	for node_index in scene_state.get_node_count():
		# ノードの所属グループに含まれていなければスキップ
		if not GROUP_NAME in scene_state.get_node_groups(node_index):
			continue
		
		var scope_id: StringName = &""
		var script: Script = null
		for prop_index in scene_state.get_node_property_count(node_index):
			var property_name := scene_state.get_node_property_name(node_index, prop_index)
			
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
		
		if not nodes_by_scope_id.has(scope_id):
			nodes_by_scope_id[scope_id] = []
		
		nodes_by_scope_id[scope_id].append(
				ScopeScanResult.new(
						scene_state.get_node_path(node_index),
						script != null,
						_check_inheritance(script),
				)
		)

	var scene_path := _get_scene_path(scene_uid)

	# 渡されたシーンごとにまとまったスコープ定義を総チェック
	for definition in definitions:
		var matched_result: Array[ScopeScanResult] = []
		matched_result.assign(nodes_by_scope_id.get(definition.scope_id, []))

		# スコープのノードが無ければ終了
		if matched_result.is_empty():
			errors.append(
					"シーン %s にスコープID '%s' が見つかりませんでした。"
					% [
						scene_path,
						definition.scope_id,
					]
			)
			continue
		
		# スコープのノードが2個以上あっても終了
		if matched_result.size() > 1:
			var error_node_paths: PackedStringArray = []
			
			for result in matched_result:
				error_node_paths.append(str(result.node_path))
			
			errors.append(
					"シーン %s でスコープID '%s' が複数ノードに存在します: %s"
					% [
						scene_path,
						definition.scope_id,
						", ".join(error_node_paths),
					]
			)
			continue

		# ここまで来た場合はmatched_resultの長さは1のみ
		# そもそもスクリプトがアタッチされていない場合も終了
		if not matched_result[0].has_script:
			errors.append(
					"シーン %s のノード %s (スコープID '%s') にスクリプトが設定されていません。"
					% [
						scene_path,
						matched_result[0].node_path,
						definition.scope_id,
					]
			)
			continue
		
		# ContainerScope以外を継承している場合も終了
		if not matched_result[0].inherits:
			errors.append(
					"シーン %s のノード %s (スコープID '%s') は ContainerScope を継承していません。"
					% [
						scene_path,
						matched_result[0].node_path,
						definition.scope_id,
					]
			)
			continue
		
	return errors


static func _get_scene_path(scene_uid: StringName) -> String:
	var resource_id := ResourceUID.text_to_id(scene_uid)
	if resource_id == ResourceUID.INVALID_ID:
		return scene_uid
	return ResourceUID.get_id_path(resource_id)

static func _check_inheritance(script: Script) -> bool:
	while script != null:
		if script == ContainerScope:
			return true
		script = script.get_base_script()
	return false


class ScopeScanResult:
	var node_path: NodePath
	var has_script: bool
	var inherits: bool

	func _init(
		init_node_path: NodePath,
		init_hsa_script: bool,
		init_inherits: bool,
	) -> void:
		node_path = init_node_path
		has_script = has_script
		inherits = init_inherits

