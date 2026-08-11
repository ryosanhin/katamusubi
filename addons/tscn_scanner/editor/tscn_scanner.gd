@tool
extends RefCounted
class_name TscnScanner

## シーン内を走査しコンテナが存在するか確認する
## [param property]: コンテナとスコープの情報
static func scan(property: ContainerScopeProperty) -> PackedStringArray:
	var errors: PackedStringArray = []
	var fs := EditorInterface.get_resource_filesystem()
	const packed_scene_string := "PackedScene"
	const script_string_name := &"script"
	
	var scene_path := ResourceUID.get_id_path(
			ResourceUID.text_to_id(property.scene_path)
	)
	
	# シーンの存在確認
	if fs.get_file_type(scene_path) != packed_scene_string:
		errors.append("%sは%sではありません。" % [scene_path, packed_scene_string])
		return errors
	
	# シーンを取得
	var packed_scene := load(scene_path) as PackedScene
	
	# シーン内容を取り出し
	var scene_state := packed_scene.get_state()
	
	# シーン内のノードを総ざらい
	for node_index in scene_state.get_node_count():
		if scene_state.get_node_path(node_index) != property.node_path:
			continue
		
		# 該当するノードのプロパティを総ざらい
		for prop_index in scene_state.get_node_property_count(node_index):
			if scene_state.get_node_property_name(node_index, prop_index) != script_string_name:
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
			
			if check_inheritance(script):
				return errors
			else:
				errors.append("%sは適切なクラスを継承していません。" % property.node_path)
			
			# スクリプトは一つだけのはずなのでここで終了
			break
		
		# 何事もなくここまで通過した場合はスクリプトがなかった場合
		errors.append("スクリプトが見つかりません。")
		break
		
	return errors

static func check_inheritance(script: Script) -> bool:
	while script != null:
		if script == AddGroupTest:
			return true
		script = script.get_base_script()
	return false
