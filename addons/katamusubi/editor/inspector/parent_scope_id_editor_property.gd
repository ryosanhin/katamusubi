@tool
extends EditorProperty
## 親スコープ選択フィールドを作成する。

const ScopeIndex := preload("../scope_index.gd")

var _candidates: Dictionary[String, StringName] = {}

var _line_edit: LineEdit
var _item_list: ItemList

var _index: ScopeIndex
var _has_pending_edit: bool = false


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

	add_focusable(_line_edit)
	add_focusable(_item_list)

	_line_edit.text_changed.connect(_on_text_changed)
	_line_edit.text_submitted.connect(_on_text_submitted)
	_line_edit.focus_exited.connect(_on_focus_exited)

	_item_list.item_selected.connect(_on_item_selected)
	_item_list.focus_exited.connect(_on_focus_exited)


func _update_property() -> void:
	var value := get_edited_object().get(get_edited_property()) as StringName
	_line_edit.text = value
	_has_pending_edit = false
	_delete_item_list_menu()


func _on_text_changed(value: String) -> void:
	_has_pending_edit = true
	_item_list.clear()

	# 空文字なら候補を非表示。
	if value.is_empty():
		_delete_item_list_menu()
		return

	# 部分一致する候補を抽出。
	var search_text := value.to_lower()
	for key in _candidates:
		var scope_id := _candidates[key]
		if search_text in scope_id.to_lower():
			_item_list.add_item(key)

	_item_list.visible = _item_list.item_count > 0


func _on_text_submitted(text: String) -> void:
	_commit_pending_edit(StringName(text))
	_delete_item_list_menu()


func _on_focus_exited() -> void:
	# フォーカスの移動先が決まってから判定する。
	_complete_focus_exit.call_deferred()


func _complete_focus_exit() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()

	# 入力欄と候補一覧の内部を移動している間は確定しない。
	if focus_owner != null:
		if (
			focus_owner == _line_edit
			or _line_edit.is_ancestor_of(focus_owner)
			or focus_owner == _item_list
			or _item_list.is_ancestor_of(focus_owner)
		):
			return

	_commit_pending_edit(StringName(_line_edit.text))
	_delete_item_list_menu()


func _on_item_selected(index: int) -> void:
	var key := _item_list.get_item_text(index)
	var value := _candidates[key]

	# コードからの text 代入では text_changed が発生しないため、
	# 候補選択による編集を明示的に記録する。
	_line_edit.text = value
	_commit_pending_edit(value)

	_delete_item_list_menu()


## 候補リストを非表示にする。
func _delete_item_list_menu() -> void:
	_item_list.visible = false


## 未確定の編集を確定する。
func _commit_pending_edit(value: StringName) -> void:
	if not _has_pending_edit:
		return

	# 通知や候補リストの非表示に伴う処理より先に確定済みにする。
	_has_pending_edit = false

	var current_value: StringName = get_edited_object().get(get_edited_property())
	if current_value == value:
		return

	emit_changed(get_edited_object(), value)


## このタイミングでのインデックスから候補を作成する。
func _get_candidate_preview() -> Dictionary[String, StringName]:
	var candidates: Dictionary[String, StringName] = {}

	for scope_snapshot in _index.scope_snapshots:
		var scene_name := ResourceUID.uid_to_path(
			scope_snapshot.scene_uid
		)
		var key := "%s::%s" % [scope_snapshot.scope_id, scene_name]
		candidates[key] = scope_snapshot.scope_id

	return candidates
