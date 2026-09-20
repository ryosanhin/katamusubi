@tool
extends EditorProperty
## 親スコープ選択フィールドを作成する。

const ScopeIndex := preload("../scope_index.gd")

var _candidates: Dictionary[String, StringName] = {}

var _line_edit: LineEdit
var _item_list: ItemList

var _index: ScopeIndex
var _last_committed_value: Variant = null


func _init(init_index: ScopeIndex) -> void:
	_index = init_index
	_candidates = _get_candidate_preview()

	var container := VBoxContainer.new()

	_line_edit = LineEdit.new()

	_item_list = ItemList.new()
	_item_list.visible = false
	_item_list.custom_minimum_size.y = 120

	container.add_child(_line_edit)
	container.add_child(_item_list)

	add_child(container)

	_line_edit.text_changed.connect(_on_text_changed)
	_line_edit.text_submitted.connect(_on_text_submitted)
	_line_edit.focus_exited.connect(_on_focus_exited)
	_item_list.item_selected.connect(_on_item_selected)


func _update_property() -> void:
	var value := get_edited_object().get(get_edited_property()) as StringName
	_line_edit.text = value
	_last_committed_value = value


func _on_text_changed(value: String) -> void:
	_item_list.clear()

	# 空文字なら候補を非表示
	if value.is_empty():
		_item_list.visible = false
		return

	# 部分一致する候補を抽出
	for key in _candidates:
		var scope_id := _candidates[key]
		if value.to_lower() in scope_id.to_lower():
			_item_list.add_item(key)
	
	_item_list.visible = _item_list.item_count > 0


func _on_text_submitted(text: String) -> void:
	_commit(StringName(text))
	_delete_item_list_menu()


func _on_focus_exited() -> void:
	_complete_focus_exit.call_deferred()


func _complete_focus_exit() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and (
			focus_owner == _item_list or _item_list.is_ancestor_of(focus_owner)
	):
		return

	_commit(StringName(_line_edit.text))
	_delete_item_list_menu()


func _on_item_selected(index: int) -> void:
	var key := _item_list.get_item_text(index)
	var value := _candidates[key]

	_commit(value)
	if _line_edit.text != value:
		_line_edit.text = value

	_delete_item_list_menu()


## 候補リストの表示を削除
func _delete_item_list_menu() -> void:
	_item_list.visible = false


## 変更を確定する。
func _commit(value: StringName) -> void:
	if _last_committed_value == value:
		return
	if get_edited_object().get(get_edited_property()) == value:
		_last_committed_value = value
		return

	_last_committed_value = value
	emit_changed(get_edited_property(), value)


## このタイミングでのインデックスから候補を作成する。
func _get_candidate_preview() -> Dictionary[String, StringName]:
	var candidates: Dictionary[String, StringName] = {}
	for scope_spanshot in _index.scope_snapshots:
		var scene_name := ResourceUID.uid_to_path(scope_spanshot.scene_uid)
		var key := "%s::%s" % [scope_spanshot.scope_id, scene_name]
		candidates[key] = scope_spanshot.scope_id
	return candidates
