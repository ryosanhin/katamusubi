@tool
extends Node
class_name AddGroupTest

func _enter_tree() -> void:
	# エディタのみで実行
	if Engine.is_editor_hint():
		if not is_in_group("test_group"):
			add_to_group("test_group", true)
			EditorInterface.mark_scene_as_unsaved()
			print("join the group")
		else:
			print("already in the group")
		return
