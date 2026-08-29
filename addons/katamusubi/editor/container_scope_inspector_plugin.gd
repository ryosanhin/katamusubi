@tool
extends EditorInspectorPlugin

const SCOPE_INDEX := preload("res://addons/katamusubi/scope_index.tres")


func _can_handle(object: Object) -> bool:
	return object is ContainerScope


func _parse_begin(object: Object) -> void:
	var target := object as ContainerScope
	var inspector_container := VBoxContainer.new()

	# スコープIDの表示
	var scope_id_display := Label.new()
	scope_id_display.text = (
		"ScopeID: %s" % target.scope_id
	)
	inspector_container.add_child(scope_id_display)

	# 親スコープ選択プルダウンメニューの説明
	var pulldown_description := Label.new()
	pulldown_description.text = (
		"Select parent scope"
	)
	inspector_container.add_child(pulldown_description)

	# 親スコープ選択プルダウンメニュー
	var pulldown_menu := OptionButton.new()
	# デフォルトの値を設定
	pulldown_menu.add_item("None")
	pulldown_menu.set_item_metadata(
			0,
			&"",
	)
	
	for scope_definition in _get_parent_scope_candidates(target):
		if scope_definition.scope_id == target.scope_id:
			continue
		
		var scene_path := _get_scene_path(scope_definition.scene_uid)

		var scene_name := scene_path.get_file()

		pulldown_menu.add_item("%s::%s" % [scene_name, scope_definition.scope_name])
		var index := pulldown_menu.item_count - 1
		pulldown_menu.set_item_metadata(
				index,
				scope_definition.scope_id,
		)
	pulldown_menu.item_selected.connect(
			_select_parent_scope.bind(pulldown_menu, target)
	)
	inspector_container.add_child(pulldown_menu)

	# UI全体を登録
	add_custom_control(inspector_container)

	# 初期値を確認
	var parent_scope_id := target.parent_scope_id

	if parent_scope_id.is_empty():
		pulldown_menu.select(0)
		return

	for item_index in pulldown_menu.item_count:
		if pulldown_menu.get_item_metadata(item_index) == parent_scope_id:
			pulldown_menu.select(item_index)
			return

	pulldown_menu.select(0)


func _select_parent_scope(
		index: int,
		pulldown_menu: OptionButton,
		target: ContainerScope,
) -> void:
	var parent_scope_id: StringName = pulldown_menu.get_item_metadata(index)
	if parent_scope_id == target.scope_id:
		push_error("自身のスコープを親スコープにすることはできません。")
		return

	var parent_scope := _get_parent_scope_candidate(parent_scope_id, target)
	if not parent_scope_id.is_empty() and parent_scope == null:
		push_error("指定されたID %s は登録されていません。" % parent_scope_id)
		return

	target.parent_scope_id = parent_scope_id
	_mark_scene_as_unsaved()


## 保存済みシーンのスコープと、現在編集中のシーン内のスコープを親候補として取得する。
## 現在のシーンについては、ScopeIndex の保存時点の情報ではなく編集中のノードを優先する。
func _get_parent_scope_candidates(target: ContainerScope) -> Array[ScopeDefinition]:
	var candidates: Array[ScopeDefinition] = []
	var scene_root := EditorInterface.get_edited_scene_root()
	if not _is_target_in_edited_scene(target, scene_root):
		return candidates

	var edited_scene_uid := _get_edited_scene_uid(scene_root)
	for snapshot in SCOPE_INDEX.scope_snapshots:
		if not edited_scene_uid.is_empty() and snapshot.scene_uid == edited_scene_uid:
			continue
		candidates.append(snapshot)

	for scope in _get_edited_scene_scopes(scene_root):
		if scope.scope_id.is_empty():
			continue
		candidates.append(ScopeDefinition.new(
				edited_scene_uid,
				scope.scope_name,
				scope.scope_id,
				scope.parent_scope_id,
		))

	return candidates


func _get_parent_scope_candidate(
	parent_scope_id: StringName,
	target: ContainerScope,
) -> ScopeDefinition:
	for candidate in _get_parent_scope_candidates(target):
		if candidate.scope_id == parent_scope_id:
			return candidate
	return null


func _get_edited_scene_scopes(scene_root: Node) -> Array[ContainerScope]:
	var scopes: Array[ContainerScope] = []
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node := stack.pop_back()
		if node == scene_root or node.owner == scene_root:
			var scope := node as ContainerScope
			if scope != null:
				scopes.append(scope)
		for index in range(node.get_child_count() - 1, -1, -1):
			stack.append(node.get_child(index))
	return scopes


func _get_edited_scene_uid(scene_root: Node) -> StringName:
	if scene_root.scene_file_path.is_empty():
		return &""
	var scene_uid := ResourceUID.path_to_uid(scene_root.scene_file_path)
	return &"" if scene_uid == scene_root.scene_file_path else scene_uid


func _get_scene_path(scene_uid: StringName) -> String:
	if scene_uid.is_empty():
		var scene_root := EditorInterface.get_edited_scene_root()
		if scene_root != null and not scene_root.scene_file_path.is_empty():
			return scene_root.scene_file_path
		return "unsaved"
	return ResourceUID.uid_to_path(scene_uid)


func _is_target_in_edited_scene(target: ContainerScope, scene_root: Node) -> bool:
	if scene_root == null:
		push_error("編集中のシーンがありません。")
		return false
	if target != scene_root and not scene_root.is_ancestor_of(target):
		push_error("コンテナスコープは編集中のシーンに属していません。")
		return false

	return true


## テスト時に未保存化の呼び出し有無を記録するための境界。
func _mark_scene_as_unsaved() -> void:
	EditorInterface.mark_scene_as_unsaved()
