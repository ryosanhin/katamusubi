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
	_switch_caution_display(value)


func _on_text_submitted(text: String) -> void:
	_commit(StringName(text))


func _on_focus_exited() -> void:
	_commit(StringName(_line_edit.text))


func _switch_caution_display(text: String) -> void:
	var edited_node := get_edited_object() as Node
	var scene_root := EditorInterface.get_edited_scene_root()
	if edited_node == null or scene_root == null or scene_root.scene_file_path.is_empty():
		_erorr_label.visible = not _index.find_by_id(text).is_empty()
		return

	var scene_uid := ResourceUID.path_to_uid(scene_root.scene_file_path)
	var is_node_in_edited_scene := scene_root == edited_node or scene_root.is_ancestor_of(edited_node)
	if scene_uid == scene_root.scene_file_path or not is_node_in_edited_scene:
		_erorr_label.visible = not _index.find_by_id(text).is_empty()
		return

	var node_path := scene_root.get_path_to(edited_node)
	_erorr_label.visible = _index.has_duplicate(text, scene_uid, node_path)


func _commit(value: StringName) -> void:
	if get_edited_object().get(get_edited_property()) == value:
		return
	emit_changed(get_edited_property(), value)
