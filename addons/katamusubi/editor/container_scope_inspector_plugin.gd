@tool
extends EditorInspectorPlugin

const SCOPE_INDEX := preload("res://addons/katamusubi/scope_index.tres")
const ParentScopeCandidates := preload("inspector/parent_scope_candidates.gd")
const ParentScopePicker := preload("inspector/parent_scope_picker.gd")

var _parent_scope_candidate_provider := ParentScopeCandidates.new(SCOPE_INDEX)


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
	var parent_scope_label := Label.new()
	parent_scope_label.text = (
		"Current parent scope"
	)
	inspector_container.add_child(parent_scope_label)

	var pulldown_factory := ParentScopePicker.new(
			target.scope_id,
			target.parent_scope_id,
	)
	# 親スコープ選択プルダウンメニューを作成
	var pulldown_menu := pulldown_factory.create(
			_parent_scope_candidate_provider.get_candidates(target, scene_root),
			scene_root,
	)
	pulldown_menu.item_selected.connect(
			_select_parent_scope.bind(pulldown_menu, target)
	)
	inspector_container.add_child(pulldown_menu)

	# UI全体を登録
	add_custom_control(inspector_container)


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

## テスト時に未保存化の呼び出し有無を記録するための境界。
func _mark_scene_as_unsaved() -> void:
	EditorInterface.mark_scene_as_unsaved()
