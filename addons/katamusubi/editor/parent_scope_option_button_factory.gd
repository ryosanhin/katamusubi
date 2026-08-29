@tool
extends RefCounted

## 親スコープ候補を表示する OptionButton の生成を担う。

var _scope_id: StringName
var _initial_selected_parent_scope: StringName


func _init(
	init_scope_id: StringName,
	init_initial_selected_parent_scope: StringName,
) -> void:
	_scope_id = init_scope_id
	_initial_selected_parent_scope = init_initial_selected_parent_scope


func create(
	definitions: Array[ScopeDefinition],
	scene_root: Node,
) -> OptionButton:
	var option_button := OptionButton.new()

	# 初期表示を追加
	option_button.add_item("None")
	option_button.set_item_metadata(0, &"")

	for def in definitions:
		if def.scope_id == _scope_id:
			continue

		var scene_path := _get_scene_path(def.scene_uid, scene_root)

		# 表示を追加
		option_button.add_item(
				"%s::%s"
				% [
						scene_path.get_file(),
						def.scope_name,
				]
		)
		# 表示に対応する値を追加
		# option_button.item_count - 1 は末尾 = 直前に追加した値に対応
		option_button.set_item_metadata(
				option_button.item_count - 1,
				def.scope_id,
		)

	_select_initial_selected_parent_scope(
			option_button,
			_initial_selected_parent_scope,
	)

	return option_button


func _select_initial_selected_parent_scope(
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
