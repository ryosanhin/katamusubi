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
		var scene_id := ResourceUID.text_to_id(scope_definition.scene_uid)
		var scene_path := ResourceUID.get_id_path(scene_id)
		var scene_name := scene_path.get_file()

		pulldown_menu.add_item("%s::%s" % [scene_name, scope_definition.scope_name])
		var index := pulldown_menu.item_count - 1
		pulldown_menu.set_item_metadata(
				index,
				scope_definition.scope_id,
		)
	pulldown_menu.item_selected.connect(
			_select_parent_scope.bind(target)
	)
	inspector_container.add_child(pulldown_menu)

	# UI全体を登録
	add_custom_control(inspector_container)

	# 初期値を確認
	var predicate := (
			func(scope_definition: ScopeDefinition) -> bool:
				return scope_definition.scope_id == target.get_parent_scope_id()
	)
	var tmp_index := DEFINITION_LIST.scope_definitions.find_custom(predicate.bind())
	if tmp_index < 0 or tmp_index > DEFINITION_LIST.scope_definitions.size():
		pulldown_menu.select(0)
		return
	pulldown_menu.select(tmp_index + 1)


func _apply_or_update(target: ContainerScope) -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
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

	var definition := DEFINITION_LIST.get_scope_definition(target.scope_id)

	if definition == null:
		# 新規登録
		var new_id := DEFINITION_LIST.get_new_id()
		target.scope_id = new_id
		EditorInterface.mark_scene_as_unsaved()
		definition = ScopeDefinition.create_new_definition(
				scene_uid,
				scene_root.get_path_to(target),
				target.scope_name,
				new_id,
				target.get_parent_scope_id(),
		)
		DEFINITION_LIST.add_scope_definitions(definition)
	else:
		# アップデート処理
		definition.scene_uid = scene_uid
		definition.node_path = scene_root.get_path_to(target)
		definition.scope_name = target.scope_name
		definition.parent_scope_id = target.get_parent_scope_id()

	_try_save_container_list()


func _delete(target: ContainerScope) -> void:
	if target.scope_id.is_empty():
		return

	var definition := DEFINITION_LIST.get_scope_definition(target.scope_id)
	if definition != null:
		DEFINITION_LIST.remove_scope_definitions(definition)
		_try_save_container_list()

	target.scope_id = &""
	EditorInterface.mark_scene_as_unsaved()


func _select_parent_scope(index:int, target: ContainerScope) -> void:
	if index == 0:
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
	
	# Noneを除外するために -1 する
	index -= 1
	var container_list := DEFINITION_LIST.scope_definitions
	var parent_scope_id := container_list[index].scope_id
	
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
	var error := ResourceSaver.save(DEFINITION_LIST, DEFINITION_LIST_PATH)
	if error != OK:
		push_error("failed save list: %s" % error_string(error))
		return false
	print("successfully saved list")
	return true
