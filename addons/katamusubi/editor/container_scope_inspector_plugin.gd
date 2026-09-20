@tool
extends EditorInspectorPlugin

const SCOPE_INDEX := preload("res://addons/katamusubi/scope_index.tres")

const ScopeIdEditorProperty := preload("inspector/scope_id_editor_property.gd")
const ParentScopeIdEditorProperty := preload("inspector/parent_scope_id_editor_property.gd")


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
	match name:
		"scope_id":
			add_property_editor(
					name,
					ScopeIdEditorProperty.new(SCOPE_INDEX)
			)
			return true
		"parent_scope_id":
			add_property_editor(
				name,
				ParentScopeIdEditorProperty.new(SCOPE_INDEX)
			)
			return true
	return false
