@tool
extends EditorInspectorPlugin
## [ContainerScope] のインスペクター表示を拡張する。

const SCOPE_INDEX := preload("res://addons/katamusubi/scope_index.tres")

const ParentScopeIdEditorProperty := preload("parent_scope_id_editor_property.gd")


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
			ParentScopeIdEditorProperty.new(SCOPE_INDEX)
		)
		return true
	
	return false
