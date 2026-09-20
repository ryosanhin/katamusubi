@tool
extends EditorProperty

const ScopeIndex := preload("../scope_index.gd")

var _candidates: PackedStringArray = []

var _line_edit: LineEdit
var _item_list: ItemList

var _index: ScopeIndex

func _init(init_index: ScopeIndex) -> void:
	_index = init_index

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


func _on_text_changed(value: String) -> void:
	_item_list.clear()

	# 空文字なら候補を非表示
	if value.is_empty():
		_item_list.visible = false
		return

	# 部分一致する候補を抽出
	_candidates = _get_candidate_preview()
	for candidate in _candidates:
		if value.to_lower() in candidate.to_lower():
			_item_list.add_item(candidate)
	
	_item_list.visible = _item_list.item_count > 0


func _on_text_submitted(text: String) -> void:
	_commit(StringName(text))
	_remove_item_list()


func _on_focus_exited() -> void:
	_commit(StringName(_line_edit.text))
	_remove_item_list()


func _on_item_selected(index: int) -> void:
	var value := _item_list.get_item_text(index)

	emit_changed(get_edited_property(), value)

	_remove_item_list()


func _remove_item_list() -> void:
	_item_list.visible = false


func _commit(value: StringName) -> void:
	if get_edited_object().get(get_edited_property()) == value:
		return

	emit_changed(get_edited_property(), value)


func _get_candidate_preview() -> PackedStringArray:
	var candidates: PackedStringArray = []
	for scope_spanshot in _index.scope_snapshots:
		candidates.append(scope_spanshot.scope_id)
	return candidates
