@tool
extends EditorInspectorPlugin

const CONTAINER_LIST := preload("res://addons/tscn_scanner/container_list.tres") 

const ENUM_PROP_NAME := "_parent_scope_id"

func _can_handle(object: Object) -> bool:
	return object is ContainerScope


func _parse_begin(object: Object) -> void:
	var target := object as ContainerScope
	var inspector_container := VBoxContainer.new()

	var apply_or_update_button := Button.new()
	apply_or_update_button.text = "Apply/Update Container"
	apply_or_update_button.pressed.connect(
		_apply_or_update.bind(target)
	)
	inspector_container.add_child(apply_or_update_button)

	var delete_button := Button.new()
	delete_button.text = "Delete Container"
	delete_button.pressed.connect(
		_delete.bind(target)
	)
	inspector_container.add_child(delete_button)

	add_custom_control(inspector_container)


func _apply_or_update(target: ContainerScope) -> void:
	print("push Apply/Update button")


func _delete(target: ContainerScope) -> void:
	print("push Delete button")