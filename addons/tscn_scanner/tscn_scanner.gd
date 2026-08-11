@tool
extends EditorPlugin

var container_list := preload("res://addons/tscn_scanner/container_list.tres")

func _build() -> bool:
	var errors: PackedStringArray = []
	for container_property in container_list.container_list:
		errors.append_array(TscnScanner.scan(container_property))

	print("エラー %d 件：\n%s" % [errors.size(), "\n".join(errors)])
		
	if errors.size() == 0:
		return true

	return false
