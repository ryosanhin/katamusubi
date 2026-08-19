@tool
extends EditorInspectorPlugin

const DEFINITION_LIST_PATH := "res://addons/tscn_scanner/scope_definition_list.tres"
const DEFINITION_LIST := preload(DEFINITION_LIST_PATH) 

const ENUM_PROP_NAME := "_parent_scope_id"

func _can_handle(object: Object) -> bool:
	return object is ContainerScope


func _parse_begin(object: Object) -> void:
	var target := object as ContainerScope
	var inspector_container := VBoxContainer.new()

	# コンテナ登録ボタン
	var apply_or_update_button := Button.new()
	apply_or_update_button.text = "Apply/Update Container"
	apply_or_update_button.pressed.connect(
		_apply_or_update.bind(target)
	)
	inspector_container.add_child(apply_or_update_button)

	# コンテナ削除ボタン
	var delete_button := Button.new()
	delete_button.text = "Delete Container"
	delete_button.pressed.connect(
		_delete.bind(target)
	)
	inspector_container.add_child(delete_button)

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
	for scope_definition in DEFINITION_LIST.scope_definitions:
		if scope_definition.scope_id == target.scope_id:
			continue
		var scene_path := ResourceUID.uid_to_path(scope_definition.scene_uid)
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
	var parent_scope_id := target.get_parent_scope_id()
	if parent_scope_id.is_empty():
		pulldown_menu.select(0)
		return

	for item_index in pulldown_menu.item_count:
		if pulldown_menu.get_item_metadata(item_index) == parent_scope_id:
			pulldown_menu.select(item_index)
			return

	pulldown_menu.select(0)


func _apply_or_update(target: ContainerScope) -> void:
	var scene_root := _get_edited_scene_root()
	if not _is_target_in_edited_scene(target, scene_root):
		return

	var scene_path := scene_root.scene_file_path
	if scene_path.is_empty():
		push_error("コンテナを登録する前にシーンを保存してください。")
		return

	var scene_uid := ResourceUID.path_to_uid(scene_path)
	if scene_uid == scene_path:
		push_error("シーンのUIDを取得できませんでした: %s" % scene_path)
		return

	var original_scope_id := target.scope_id
	var definition := DEFINITION_LIST.get_scope_definition(target.scope_id)

	if definition == null:
		# 新規登録
		var new_id := DEFINITION_LIST.get_new_id()
		if new_id.is_empty():
			push_error("空のスコープIDでは登録できません")
			return
		var new_definition := ScopeDefinition.create_new_definition(
				scene_uid,
				target.scope_name,
				new_id,
				target.get_parent_scope_id(),
		)
		var rollback_action := DEFINITION_LIST.add_scope_definition(new_definition)
		if not _try_save_container_list():
			rollback_action.rollback()
			target.scope_id = original_scope_id
			return

		target.scope_id = new_id
	else:
		var rollback_action := DEFINITION_LIST.update_scope_definition(
				target.scope_id,
				scene_uid,
				target.scope_name,
				target.get_parent_scope_id(),
		)
		# 保存失敗時はデータを基に戻す
		if not _try_save_container_list():
			rollback_action.rollback()
			return

	if target.scope_id != original_scope_id:
		_mark_scene_as_unsaved()


func _delete(target: ContainerScope) -> void:
	if target.scope_id.is_empty():
		return
	
	var rollback_action := DEFINITION_LIST.remove_scope_definition(target.scope_id)
	if not _try_save_container_list():
		rollback_action.rollback()
		return

	target.scope_id = &""
	_mark_scene_as_unsaved()


func _select_parent_scope(
		index: int,
		pulldown_menu: OptionButton,
		target: ContainerScope,
) -> void:
	var parent_scope_id: StringName = pulldown_menu.get_item_metadata(index)
	if parent_scope_id.is_empty():
		# 対象スコープに登録されている親スコープ情報を削除
		var target_scope_definition := DEFINITION_LIST.get_scope_definition(
				target.scope_id
		)
		if target_scope_definition == null:
			push_error("対象のスコープ定義が登録されていません: %s" % target.scope_id)
			return

		target_scope_definition.parent_scope_id = &""
		_try_save_container_list()
		return

	if parent_scope_id == target.scope_id:
		push_error("自身のスコープを親スコープにすることはできません。")
		return

	var parent_scope := DEFINITION_LIST.get_scope_definition(parent_scope_id)

	if parent_scope == null:
		push_error("指定されたID %s は登録されていません。" % parent_scope_id)
		return

	# スコープの登録情報にも参照先親スコープを登録
	var target_scope_definition := DEFINITION_LIST.get_scope_definition(target.scope_id)
	target_scope_definition.parent_scope_id = parent_scope_id
	_try_save_container_list()

	EditorInterface.mark_scene_as_unsaved()


func _is_target_in_edited_scene(target: ContainerScope, scene_root: Node) -> bool:
	if scene_root == null:
		push_error("編集中のシーンがありません。")
		return false
	if target != scene_root and not scene_root.is_ancestor_of(target):
		push_error("コンテナスコープは編集中のシーンに属していません。")
		return false

	return true


func _try_save_container_list() -> bool:
	var error := _save_container_list()
	if error != OK:
		push_error("failed save list: %s" % error_string(error))
		return false
	print("successfully saved list")
	return true


## テスト用サブクラスで保存結果を決定的に差し替えるための境界。
func _save_container_list() -> Error:
	return ResourceSaver.save(DEFINITION_LIST, DEFINITION_LIST_PATH)


## テスト時に編集中のシーンを差し替えるための境界。
func _get_edited_scene_root() -> Node:
	return EditorInterface.get_edited_scene_root()


## テスト時に未保存化の呼び出し有無を記録するための境界。
func _mark_scene_as_unsaved() -> void:
	EditorInterface.mark_scene_as_unsaved()
