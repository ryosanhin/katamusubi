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
	if _is_instanced_root_node():
		_line_edit.editable = false
		return
	_switch_caution_display(value)


func _on_text_submitted(text: String) -> void:
	_commit(StringName(text))


func _on_focus_exited() -> void:
	_commit(StringName(_line_edit.text))


## 重複警告表示の状態を切り替える
func _switch_caution_display(text: String) -> void:
	var edited_node := get_edited_object() as Node
	var edited_scene_root := EditorInterface.get_edited_scene_root()
	if (
			edited_node == null
			or edited_scene_root == null
			or edited_scene_root.scene_file_path.is_empty()
	):
		_erorr_label.visible = not _index.find_by_id(text).is_empty()
		return

	var scene_uid := ResourceUID.path_to_uid(edited_scene_root.scene_file_path)
	var is_unsaved_scene := scene_uid == edited_scene_root.scene_file_path
	if is_unsaved_scene:
		_erorr_label.visible = not _index.find_by_id(text).is_empty()
		return

	var node_path := _to_scene_state_path(edited_scene_root.get_path_to(edited_node))
	_erorr_label.visible = _index.has_duplicate(text, scene_uid, node_path)


## 変更を確定する。
func _commit(value: StringName) -> void:
	if _is_instanced_root_node():
		return
	if get_edited_object().get(get_edited_property()) == value:
		return
	emit_changed(get_edited_property(), value)


## [SceneState] の [code]get_node_path()[/code] パスに形式を合わせる。
func _to_scene_state_path(node_path: NodePath) -> NodePath:
	if node_path == ^".":
		return node_path

	return NodePath("./" + str(node_path))


## 自身が他の[PackedScene] のインスタンスかどうか調べる。[br]
## インスタンスならば編集はインスタンス元のシーンで編集をして。
func _is_instanced_root_node() -> bool:
	var edited_node := get_edited_object() as Node
	var edited_scene_root := EditorInterface.get_edited_scene_root()
	
	var is_root_node := edited_node == edited_scene_root
	var has_scene_file_path := not edited_node.scene_file_path.is_empty()

	# ルートノードではないのに、シーンファイルのパスを持っている
	# つまり、PackedSceneのインスタンスである
	return not is_root_node and has_scene_file_path
