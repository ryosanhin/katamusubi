@tool
extends EditorProperty

const ScopeIndex := preload("../scope_index.gd")

var _line_edit: LineEdit
var _erorr_label: Label

var _index: ScopeIndex


func _init(init_index: ScopeIndex) -> void:
	_index = init_index

	var container := VBoxContainer.new()

	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "empty = private scope"
	_line_edit.text_submitted.connect(_on_text_submitted)
	_line_edit.focus_exited.connect(_on_focus_exited)
	container.add_child(_line_edit)

	_erorr_label = Label.new()
	_erorr_label.text = "duplicated id is not allowed"
	_erorr_label.visible = false
	_line_edit.text_changed.connect(_switch_caution_display)
	container.add_child(_erorr_label)

	add_child(container)


func _update_property() -> void:
	var value := get_edited_object().get(get_edited_property()) as StringName
	_line_edit.text = value


func _on_text_submitted(text: String) -> void:
	_commit(StringName(text))


func _on_focus_exited() -> void:
	_commit(StringName(_line_edit.text))


func _switch_caution_display(text: String) -> void:
	if _index.find_by_id(text).is_empty():
		_erorr_label.visible = false
	else:
		_erorr_label.visible = true


func _commit(value: StringName) -> void:
	if get_edited_object().get(get_edited_property()) == value:
		return
	emit_changed(get_edited_property(), value)
