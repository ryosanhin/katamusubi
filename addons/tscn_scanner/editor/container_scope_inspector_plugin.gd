@tool
extends EditorInspectorPlugin

const CONTAINER_LIST := preload("res://addons/tscn_scanner/container_list.tres") 

const ENUM_PROP_NAME := "_parent_scope_id"
const CONTAINER_LIST_PATH := "res://addons/tscn_scanner/container_list.tres"

func _can_handle(object: Object) -> bool:
	return object is ContainerScope


func _parse_begin(object: Object) -> void:
	var target := object as ContainerScope
	var inspector_container := VBoxContainer.new()

	var apply_or_update_button := Button.new()
	apply_or_update_button.text = "Apply/Update Container"
	apply_or_update_button.pressed.connect(
		_apply_or_update.bind(target)
	)
	inspector_container.add_child(apply_or_update_button)

	var delete_button := Button.new()
	delete_button.text = "Delete Container"
	delete_button.pressed.connect(
		_delete.bind(target)
	)
	inspector_container.add_child(delete_button)

	add_custom_control(inspector_container)


func _apply_or_update(target: ContainerScope) -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not _is_target_in_edited_scene(target, scene_root):
		return

	var scene_path := scene_root.scene_file_path
	if scene_path.is_empty():
		push_error("コンテナを登録する前にシーンを保存してください。")
		return

	var scene_uid := ResourceUID.get_id_for_path(scene_path)
	if scene_uid == ResourceUID.INVALID_ID:
		push_error("シーンのUIDを取得できませんでした: %s" % scene_path)
		return

	var scene_uid_text := ResourceUID.id_to_text(scene_uid)
	var property := _find_property(target.scope_uid)
	if property != null and not _property_belongs_to_target(
			property,
			target,
			scene_root,
			scene_uid_text
	):
		target._scope_uid = &""
		property = null

	if property == null:
		property = ContainerScopeProperty.new()
		if target.scope_uid.is_empty():
			target._scope_uid = CONTAINER_LIST.get_new_uid(ContainerScope.UID_LENGTH)
			EditorInterface.mark_scene_as_unsaved()
		property._scope_uid = target.scope_uid
		CONTAINER_LIST._container_list.append(property)

	property._scene_uid = scene_uid_text
	property._node_path = scene_root.get_path_to(target)
	property._scope_id = target.scope_id
	property._parent_scope_id = target.parent_scope_id

	_save_container_list()


func _delete(target: ContainerScope) -> void:
	if target.scope_uid.is_empty():
		return

	var property := _find_property(target.scope_uid)
	if property != null:
		CONTAINER_LIST._container_list.erase(property)
		_save_container_list()

	target._scope_uid = &""
	EditorInterface.mark_scene_as_unsaved()


func _find_property(scope_uid: StringName) -> ContainerScopeProperty:
	if scope_uid.is_empty():
		return null

	for property in CONTAINER_LIST._container_list:
		if property.scope_uid == scope_uid:
			return property

	return null


func _is_target_in_edited_scene(target: ContainerScope, scene_root: Node) -> bool:
	if scene_root == null:
		push_error("編集中のシーンがありません。")
		return false
	if target != scene_root and not scene_root.is_ancestor_of(target):
		push_error("コンテナスコープは編集中のシーンに属していません。")
		return false

	return true


func _property_belongs_to_target(
		property: ContainerScopeProperty,
		target: ContainerScope,
		scene_root: Node,
		scene_uid: String
) -> bool:
	if property.scene_uid != scene_uid:
		return false

	var registered_node := scene_root.get_node_or_null(property.node_path)
	return registered_node == null or registered_node == target


func _save_container_list() -> void:
	var error := ResourceSaver.save(CONTAINER_LIST, CONTAINER_LIST_PATH)
	if error != OK:
		push_error("コンテナリストの保存に失敗しました: %s" % error_string(error))
