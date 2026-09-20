@tool
extends EditorInspectorPlugin

const SCOPE_INDEX := preload("res://addons/katamusubi/scope_index.tres")
const ParentScopeCandidates := preload("inspector/parent_scope_candidates.gd")
const ParentScopePicker := preload("inspector/parent_scope_picker.gd")
var _provider := ParentScopeCandidates.new(SCOPE_INDEX)


func _can_handle(object: Object) -> bool:
	return object is ContainerScope


func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	if name != "scope_id" and name != "parent_scope_id":
		return false
	var target := object as ContainerScope
	var root := EditorInterface.get_edited_scene_root()
	if name == "scope_id":
		var edit := LineEdit.new()
		edit.text = target.scope_id
		edit.placeholder_text = "空欄＝非公開"
		edit.text_submitted.connect(_commit.bind(target, &"scope_id"))
		edit.focus_exited.connect(func() -> void: _commit(edit.text, target, &"scope_id"))
		add_property_editor(name, edit, false, "公開スコープ名")
	else:
		var picker := ParentScopePicker.new(target.parent_scope_id, _provider.get_candidates(target, root), root)
		picker.value_committed.connect(_commit.bind(target, &"parent_scope_id"))
		add_property_editor(name, picker, false, "親スコープ名")
		_add_diagnostics(target, root)
	return true


func _commit(value: StringName, target: ContainerScope, property: StringName) -> void:
	if target.get(property) == value:
		return
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("スコープ名を変更")
	undo.add_do_property(target, property, value)
	undo.add_undo_property(target, property, target.get(property))
	undo.commit_action()


func _add_diagnostics(target: ContainerScope, root: Node) -> void:
	if target.parent_scope_id.is_empty():
		return
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if target.parent_scope_id == target.scope_id:
		label.text = "警告: 自身と同じ公開名が親に指定されています。"
	else:
		var matches := _provider.get_candidates_by_id(target.parent_scope_id, target, root)
		if matches.is_empty():
			label.text = "警告: 現在の索引では親が見つかりません。入力値は保持されます。"
		elif matches.size() > 1:
			label.text = "警告: 同名の親候補が%d件あり曖昧です。実行時にも一意である必要があります。" % matches.size()
	if not label.text.is_empty():
		add_custom_control(label)
	else:
		label.free()
