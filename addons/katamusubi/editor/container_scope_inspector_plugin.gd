@tool
extends EditorInspectorPlugin

const SCOPE_INDEX := preload("res://addons/katamusubi/scope_index.tres")
const ParentScopeCandidateProvider := preload(
		"res://addons/katamusubi/editor/parent_scope_candidate_provider.gd"
)

var _parent_scope_candidate_provider := ParentScopeCandidateProvider.new(SCOPE_INDEX)


func _can_handle(object: Object) -> bool:
	return object is ContainerScope


func _parse_begin(object: Object) -> void:
	var target := object as ContainerScope
	var scene_root := EditorInterface.get_edited_scene_root()
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
	
	for scope_definition in _parent_scope_candidate_provider.get_candidates(
		target,
		scene_root,
	):
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

	var scene_root := EditorInterface.get_edited_scene_root()
	var parent_scope := _parent_scope_candidate_provider.get_candidate(
		parent_scope_id,
		target,
		scene_root,
	)
	if not parent_scope_id.is_empty() and parent_scope == null:
		push_error("指定されたID %s は登録されていません。" % parent_scope_id)
		return

	target.parent_scope_id = parent_scope_id
	_mark_scene_as_unsaved()

func _get_scene_path(scene_uid: StringName) -> String:
	if scene_uid.is_empty():
		var scene_root := EditorInterface.get_edited_scene_root()
		if scene_root != null and not scene_root.scene_file_path.is_empty():
			return scene_root.scene_file_path
		return "unsaved"
	return ResourceUID.uid_to_path(scene_uid)

## テスト時に未保存化の呼び出し有無を記録するための境界。
func _mark_scene_as_unsaved() -> void:
	EditorInterface.mark_scene_as_unsaved()
