@tool
extends RefCounted

## 親スコープ候補を表示する OptionButton の生成を担う。

var _current_scope_id: StringName
var _selected_parent_scope_id: StringName


func _init(
	init_current_scope_id: StringName,
	init_selected_parent_scope_id: StringName,
) -> void:
	_current_scope_id = init_current_scope_id
	_selected_parent_scope_id = init_selected_parent_scope_id


func create(
	candidates: Array[ScopeDefinition],
	scene_root: Node,
) -> OptionButton:
	var option_button := OptionButton.new()

	# 初期表示を追加
	option_button.add_item("None")
	option_button.set_item_metadata(0, &"")

	for candidate in candidates:
		if candidate.scope_id == _current_scope_id:
			continue

		var scene_path := _get_scene_path(candidate.scene_uid, scene_root)

		# 表示を追加
		option_button.add_item(
				"%s::%s"
				% [
						scene_path.get_file(),
						candidate.scope_name,
				]
		)
		# 表示に対応する値を追加
		# option_button.item_count - 1 は末尾 = 直前に追加した値に対応
		option_button.set_item_metadata(
				option_button.item_count - 1,
				candidate.scope_id,
		)

	_select_parent_scope_id(
			option_button,
			_selected_parent_scope_id,
	)

	return option_button


func _select_parent_scope_id(
	option_button: OptionButton,
	parent_scope_id: StringName,
) -> void:
	for item_index in option_button.item_count:
		if option_button.get_item_metadata(item_index) == parent_scope_id:
			option_button.select(item_index)
			return

	option_button.select(0)


func _get_scene_path(scene_uid: StringName, scene_root: Node) -> String:
	if scene_uid.is_empty():
		if scene_root != null and not scene_root.scene_file_path.is_empty():
			return scene_root.scene_file_path
		return "unsaved"
	return ResourceUID.uid_to_path(scene_uid)
