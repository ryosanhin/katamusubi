@tool
extends VBoxContainer

## Searchable suggestions around a free-form parent name input.
signal value_committed(value: StringName)

var _candidates: Array[ScopeSnapshot]
var _scene_root: Node
var _line_edit := LineEdit.new()
var _suggestions := ItemList.new()


func _init(value: StringName = &"", candidates: Array[ScopeSnapshot] = [], scene_root: Node = null) -> void:
	_candidates = candidates
	_scene_root = scene_root
	_line_edit.text = value
	_line_edit.placeholder_text = "空欄＝親なし（任意の公開名を入力できます）"
	_line_edit.text_changed.connect(_filter)
	_line_edit.text_submitted.connect(func(text: String) -> void: value_committed.emit(StringName(text)))
	_line_edit.focus_exited.connect(func() -> void: value_committed.emit(StringName(_line_edit.text)))
	add_child(_line_edit)
	_suggestions.custom_minimum_size.y = 90
	_suggestions.item_selected.connect(_select_suggestion)
	add_child(_suggestions)
	_filter(value)


func get_line_edit() -> LineEdit:
	return _line_edit


func _filter(query: String) -> void:
	_suggestions.clear()
	var counts: Dictionary[StringName, int] = {}
	for candidate in _candidates:
		if query.is_empty() or query.to_lower() in String(candidate.scope_id).to_lower():
			counts[candidate.scope_id] = counts.get(candidate.scope_id, 0) + 1
	for candidate in _candidates:
		if not query.is_empty() and not query.to_lower() in String(candidate.scope_id).to_lower():
			continue
		var scene := _scene_label(candidate.scene_uid)
		var duplicate := " [曖昧: 同名%d件]" % counts[candidate.scope_id] if counts[candidate.scope_id] > 1 else ""
		_suggestions.add_item("%s — %s :: %s%s" % [candidate.scope_id, scene, candidate.node_path, duplicate])
		_suggestions.set_item_metadata(_suggestions.item_count - 1, candidate.scope_id)


func _select_suggestion(index: int) -> void:
	_line_edit.text = String(_suggestions.get_item_metadata(index))
	value_committed.emit(StringName(_line_edit.text))


func _scene_label(uid: StringName) -> String:
	if uid.is_empty():
		return "未保存シーン"
	var path := ResourceUID.uid_to_path(uid)
	return path if not path.is_empty() else String(uid)
