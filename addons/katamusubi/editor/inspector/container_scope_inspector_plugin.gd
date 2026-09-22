@tool
extends EditorInspectorPlugin
## [ContainerScope] のインスペクター表示を拡張する。

const ParentScopeIdEditorProperty := preload("parent_scope_id_editor_property.gd")
const ScopeIndex := preload("../scope_index.gd")

var _scope_index: ScopeIndex


func _init(scope_index: ScopeIndex) -> void:
	_scope_index = scope_index


func _can_handle(object: Object) -> bool:
	return object is ContainerScope


func _parse_property(
		object: Object,
		_type: Variant.Type,
		name: String,
		_hint_type: PropertyHint,
		_hint_string: String,
		_usage_flags: int,
		_wide: bool,
) -> bool:
	if name == "parent_scope_id":
		add_property_editor(
			name,
			ParentScopeIdEditorProperty.new(_scope_index)
		)
		return true
	
	return false
