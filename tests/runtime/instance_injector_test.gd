extends SceneTree

const InstanceInjector := preload(
		"res://addons/katamusubi/runtime/injection/instance_injector.gd"
)
const GlobalService := preload("fixtures/global_service.gd")
const AnonymousService := preload("fixtures/anonymous_service.gd")
const GlobalClassTarget := preload("fixtures/global_class_target.gd")
const AnonymousClassTarget := preload("fixtures/anonymous_class_target.gd")
const UnresolvedClassTarget := preload("fixtures/unresolved_class_target.gd")

var _failures: PackedStringArray = []


func _init() -> void:
	_test_global_class_type()
	_test_anonymous_class_type_with_override()
	_test_unresolved_type_without_override()

	if _failures.is_empty():
		print("InstanceInjector tests passed")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_global_class_type() -> void:
	var service := GlobalService.new()
	var target := GlobalClassTarget.new()
	root.add_child(target)
	var injector := _injector_with_service(service, GlobalService)

	var succeeded := injector.try_inject_arguments(target)

	_expect(succeeded, "グローバルクラス型を解決できる")
	_expect(target.injected_service == service, "グローバルクラス型を注入できる")
	target.queue_free()


func _test_anonymous_class_type_with_override() -> void:
	var service := AnonymousService.new()
	var target := AnonymousClassTarget.new()
	root.add_child(target)
	var injector := _injector_with_service(service, AnonymousService)

	var succeeded := injector.try_inject_arguments(target)

	# 正常終了は、型の読み取り時に誤ってエラーを記録せず、
	# オーバーライド適用後の型で解決できたことを示す。
	_expect(succeeded, "無名クラス型をオーバーライドで解決できる")
	_expect(target.injected_service == service, "無名クラス型を注入できる")
	target.queue_free()


func _test_unresolved_type_without_override() -> void:
	var target := UnresolvedClassTarget.new()
	root.add_child(target)
	var injector := InstanceInjector.new(InjectionContainer.new(null), &"test")

	_expect(
			not injector.try_inject_arguments(target),
			"型オーバーライドのない解決不能な型は注入に失敗する",
	)
	target.queue_free()


func _injector_with_service(instance: Variant, type: Script) -> InstanceInjector:
	var container := InjectionContainer.new(null)
	container.register(ServiceRegistration.create_instance_registration(instance, type))
	return InstanceInjector.new(container, &"test")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
