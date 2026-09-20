@tool
extends EditorProperty

const ScopeIndex := preload("../scope_index.gd")

var _line_edit: LineEdit

var _index: ScopeIndex


func _init(init_index: ScopeIndex) -> void:
	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "empty = private scope"
	_line_edit.text_submitted.connect(_on_text_submitted)
	_line_edit.focus_exited.connect(_on_focus_exited)
	add_child(_line_edit)


func _update_property() -> void:
	var value := get_edited_object().get(get_edited_property()) as StringName
	_line_edit.text = value


func _on_text_submitted(text: String) -> void:
	_commit(StringName(text))


func _on_focus_exited() -> void:
	_commit(StringName(_line_edit.text))


func _commit(value: StringName) -> void:
	if get_edited_object().get(get_edited_property()) == value:
		return

	emit_changed(get_edited_property(), value)
