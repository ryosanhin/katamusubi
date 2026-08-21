@tool
extends RefCounted
class_name TscnScanner

const GROUP_NAME := &"test_group"
const SCOPE_ID_STRING_NAME := &"scope_id"
const SCRIPT_STRING_NAME := &"script"

var new_scope_ids: Array[StringName]
var continuous_scopeids: Array[StringName]
var deleted_scope_ids: Array[StringName]

var _scene_uid: StringName
var _definitions: Array[ScopeDefinition]
var _snapshot: SceneScopeSnapshot

func _init(
	init_scene_uid: StringName,
	init_definitions: Array[ScopeDefinition]
) -> void:
	_scene_uid = init_scene_uid
	_definitions = init_definitions
	_snapshot = _scan_scene(init_scene_uid)


func get_scene_scope_diff() -> Dictionary:
	var existing_scope_ids := _snapshot.get_existing_scope_ids()

	var existed_scope_ids := _definitions.map(
			func(def: ScopeDefinition) -> StringName:
				return def.scope_id
	)

	var result: Dictionary[String, Array] = {}
	result["deleted"] = []
	result["continuous"] = []
	result["new"] = []

	# 継続して存在するスコープと削除されていたスコープを抽出
	while not existed_scope_ids.is_empty():
		var existed_scope_id := existed_scope_ids.pop_back()
		if existed_scope_id in existing_scope_ids:
			result["continuous"].append(existed_scope_id)
		else:
			result["deleted"].append(existed_scope_id)
	
	# 新規作成されたスコープを抽出
	for existing_scope_id in existing_scope_ids:
		if not existing_scope_id in result["continuous"]:
			result["new"].append(existing_scope_id)

	return result




## 一つのシーンを走査し、同シーンに属するすべてのスコープ定義を確認する[br]
## [param scene_uid]: 調べたいシーンのUID[br]
## [param definitions]: そのシーンに所属していると思われるスコープ定義群[br]
## returns: エラー一覧
func static_scan(
	scene_uid: StringName,
	definitions: Array[ScopeDefinition],
) -> PackedStringArray:
	var errors: PackedStringArray = []
	
	var scene_path := ResourceUID.uid_to_path(scene_uid)

	var existing_scope_ids := _snapshot.get_existing_scope_ids()
	
	# 渡されたシーンごとにまとまったスコープ定義を総チェック
	for definition in _definitions:

		# スコープのノードが無ければ終了
		if existing_scope_ids.is_empty():
			errors.append(
					"シーン %s にスコープID '%s' が見つかりませんでした。"
					% [
						scene_path,
						definition.scope_id,
					]
			)
			continue
		
		# スコープのノードが2個以上あっても終了
		if existing_scope_ids.count(definition.scope_id) > 1:
			var error_node_paths: PackedStringArray = []			
			errors.append(
					"シーン %s でスコープID '%s' が複数ノードに存在します"
					% [
						scene_path,
						definition.scope_id,
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


## [code]SceneState[/code]を利用してシーン内を走査[br]
## シーンが存在しない場合は[code]null[/code]を返す[br]
## [param scene_uid]: 検索したいシーンのUID[br]
## returns: SceneScopeSnapshot
func _scan_scene(
	scene_uid: StringName
) -> SceneScopeSnapshot:
	var entries: Array[ScannedEntry] = []

	var packed_scene := load(scene_uid) as PackedScene
	
	if packed_scene == null:
		push_error("シーン %s が存在しません。" % scene_uid)
		return null

	var scene_state := packed_scene.get_state()

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

		entries.append(
				ScannedEntry.new(
					scene_uid,
					scope_id,
					scene_state.get_node_path(node_index),
					script != null,
					_check_inheritance(script),
				)
		)
	
	return SceneScopeSnapshot.new(scene_uid, entries)


func _check_inheritance(script: Script) -> bool:
	while script != null:
		if script == ContainerScope:
			return true
		script = script.get_base_script()
	return false
