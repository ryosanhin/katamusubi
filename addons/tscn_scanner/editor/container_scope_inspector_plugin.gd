@tool
extends EditorInspectorPlugin

const CONTAINER_LIST_PATH := "res://addons/tscn_scanner/container_list.tres"
const CONTAINER_LIST := preload(CONTAINER_LIST_PATH) 

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
	var id_pairs := CONTAINER_LIST.get_id_pairs()
	# デフォルトの値を設定
	pulldown_menu.add_item("None")
	pulldown_menu.set_item_metadata(
			0,
			&"",
	)
	for scope_name in CONTAINER_LIST.get_id_pairs():
		pulldown_menu.add_item(scope_name)
		var index := pulldown_menu.item_count - 1
		pulldown_menu.set_item_metadata(
				index,
				id_pairs[scope_name],
		)
	pulldown_menu.item_selected.connect(
			_select_parent_scope.bind(target)
	)
	inspector_container.add_child(pulldown_menu)

	add_custom_control(inspector_container)


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

	var property := CONTAINER_LIST.get_container_scope_property_with_scope_id(target.scope_uid)

	if property == null:
		var new_uid := CONTAINER_LIST.get_new_id()
		target._scope_uid = new_uid
		property = ContainerScopeProperty.create_new_property(
				scene_uid,
				scene_root.get_path_to(target),
				target.scope_name,
				new_uid,
				target.parent_scope_name,
		)
		CONTAINER_LIST.add_container(property)
	else:
		property.scene_uid = scene_uid
		property.node_path = scene_root.get_path_to(target)
		property.scope_name = target.scope_name
		property.parent_scope_id = target.parent_scope_name

	_save_container_list()


func _delete(target: ContainerScope) -> void:
	if target.scope_uid.is_empty():
		return

	var property := CONTAINER_LIST.get_container_scope_property_with_scope_id(target.scope_uid)
	if property != null:
		CONTAINER_LIST.remove_container(property)
		_save_container_list()

	target._scope_uid = &""
	EditorInterface.mark_scene_as_unsaved()


func _select_parent_scope(index:int, target: ContainerScope) -> void:
	if index == 0:
		target.parent_scope_name = &""
		target.parent_scope_id = &""
		return
	
	# Noneを除外するために -1 する
	index -= 1
	var id_pairs := CONTAINER_LIST.get_id_pairs()
	var ids: Array[StringName] = []
	ids.assign(id_pairs.values())
	var value := ids[index]
	target.parent_scope_name = id_pairs.keys()[index]
	target.parent_scope_id = value


func _is_target_in_edited_scene(target: ContainerScope, scene_root: Node) -> bool:
	if scene_root == null:
		push_error("編集中のシーンがありません。")
		return false
	if target != scene_root and not scene_root.is_ancestor_of(target):
		push_error("コンテナスコープは編集中のシーンに属していません。")
		return false

	return true


func _save_container_list() -> void:
	var error := ResourceSaver.save(CONTAINER_LIST, CONTAINER_LIST_PATH)
	if error != OK:
		push_error("コンテナリストの保存に失敗しました: %s" % error_string(error))
	print("successfully saved")
