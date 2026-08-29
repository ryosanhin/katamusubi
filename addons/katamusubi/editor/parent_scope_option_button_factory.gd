@tool
extends RefCounted

## 親スコープ候補を表示する OptionButton の生成を担う。

const ParentScopeCandidateProvider := preload(
		"res://addons/katamusubi/editor/parent_scope_candidate_provider.gd"
)

var _candidate_provider: ParentScopeCandidateProvider


func _init(candidate_provider: ParentScopeCandidateProvider) -> void:
	_candidate_provider = candidate_provider


func create(target: ContainerScope, scene_root: Node) -> OptionButton:
	var option_button := OptionButton.new()
	_add_item(option_button, "None", &"")

	for scope_definition in _candidate_provider.get_candidates(target, scene_root):
		if scope_definition.scope_id == target.scope_id:
			continue

		var scene_path := _get_scene_path(scope_definition.scene_uid, scene_root)
		_add_item(
				option_button,
				"%s::%s" % [scene_path.get_file(), scope_definition.scope_name],
				scope_definition.scope_id,
		)

	_select_parent_scope(option_button, target.parent_scope_id)
	return option_button


func _add_item(
	option_button: OptionButton,
	label: String,
	scope_id: StringName,
) -> void:
	option_button.add_item(label)
	option_button.set_item_metadata(option_button.item_count - 1, scope_id)


func _select_parent_scope(
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
