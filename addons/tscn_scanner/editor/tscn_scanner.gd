@tool
extends RefCounted
class_name TscnScanner

## シーン内を走査しコンテナスコープが存在するか確認する
## [param property]: コンテナとスコープの情報
static func scan(property: ContainerScopeProperty) -> PackedStringArray:
	var errors: PackedStringArray = []
	const PACKED_SCENE_STRING := "PackedScene"
	const SCRIPT_STRING_NAME := &"script"
	
	# シーンを取得
	var packed_scene := load(property.scene_uid) as PackedScene
	
	if packed_scene == null:
		errors.append("シーンが存在しません。")
		return errors

	# シーン内容を取り出し
	var scene_state := packed_scene.get_state()
	
	# シーン内のノードを総ざらい
	for node_index in scene_state.get_node_count():
		if scene_state.get_node_path(node_index) != property.node_path:
			continue
		
		# 該当するノードのプロパティを総ざらい
		for prop_index in scene_state.get_node_property_count(node_index):
			if scene_state.get_node_property_name(node_index, prop_index) != SCRIPT_STRING_NAME:
				continue

			# スクリプトがあればそれを読み込み
			var script := scene_state.get_node_property_value(
					node_index,
					prop_index
			) as Script
			
			# 空またはキャストに失敗した場合
			if script == null:
				errors.append("スクリプトの読み込みに失敗しました。")
				return errors
			
			# 読み込んだスクリプトがコンテナスコープスクリプトを継承しているか確認
			if check_inheritance(script):
				return errors
			else:
				errors.append("%sは適切なクラスを継承していません。" % property.node_path)
			
			# スクリプトは一つだけのはずなのでここで終了
			errors.append("%sに適切なスクリプトが見つかりませんでした。" % property.node_path)
			break
	
	var scene_path := ResourceUID.get_id_path(
			ResourceUID.text_to_id(property.scene_path)
	)

	errors.append("シーン %s に対象のノードが見つかりませんでした。" % scene_path)

	return errors

static func check_inheritance(script: Script) -> bool:
	while script != null:
		if script == ContainerScope:
			return true
		script = script.get_base_script()
	return false
