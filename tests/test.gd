extends SceneTree

func _init() -> void:
	var test_root_scene := preload("res://tests/test_root.tscn")
	var test_root_scene_instance := test_root_scene.instantiate()
	root.add_child(test_root_scene_instance)
	
	var test_child_scene := preload("res://tests/test_child.tscn")
	var test_child_scene_instance := test_child_scene.instantiate()
	test_root_scene_instance.add_child(test_child_scene_instance)

	var test_root_user := test_root_scene_instance.find_child("User*", false)
	var test_child_user := test_child_scene_instance.find_child("User*", false)

	_call_method.call_deferred(test_root_user, test_child_user)


func _call_method(test_root_user, test_child_user) -> void:
	var exit_code := 0

	print(test_root_user.call_injected_instance())
	if test_root_user.call_injected_instance() != "call from test root user":
		exit_code += 1<<0

	print(test_child_user.call_injected_instance())
	if test_child_user.call_injected_instance() != "call from test child user":
		exit_code += 1<<1

	_exit.call_deferred(exit_code)


func _exit(exit_code: int) -> void:
	quit(exit_code)
