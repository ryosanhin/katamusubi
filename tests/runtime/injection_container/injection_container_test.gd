extends SceneTree


const BaseService := preload("fixtures/services/base_service.gd")
const DerivedService := preload("fixtures/services/derived_service.gd")
const TrackedService := preload("fixtures/services/tracked_service.gd")
const UnrelatedService := preload("fixtures/services/unrelated_service.gd")

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_default_resolution()
	_test_singleton()
	_test_transient()
	_test_instance_registration()
	_test_invalid_instance_registrations()
	_test_key_precedence_and_default_fallback()
	_test_parent_lookup_order()
	_test_duplicate_registrations()
	_test_key_scopes()
	_test_invalid_registration()
	_test_null_registration()
	_test_unregistered_service()
	_test_clear()
	_test_empty_and_nonempty_keys_do_not_collide()

	await _runner.finish(self, "InjectionContainer")


func _test_default_resolution() -> void:
	_runner.change_test_name("default_resolution")
	var container := InjectionContainer.new(null)
	var succeeded := container.register(_class_registration(TrackedService, Lifecycle.Type.TRANSIENT))

	var resolved = container.resolve(TrackedService, &"")
	_runner.assert_true(succeeded, "正常な登録は成功を返す")
	_runner.assert_true(resolved is InjectionContainerTestTrackedService, "Scriptからデフォルト登録を解決する")


func _test_singleton() -> void:
	_runner.change_test_name("singleton")
	TrackedService.reset_generation_count()
	var container := InjectionContainer.new(null)
	container.register(_class_registration(TrackedService, Lifecycle.Type.SINGLETON))
	var first = container.resolve(TrackedService, &"")
	var second = container.resolve(TrackedService, &"")

	_runner.assert_same(second, first, "Singletonは同じ参照を返す")
	_runner.assert_equal(TrackedService.generation_count, 1, "Singletonを一度だけ生成する")


func _test_transient() -> void:
	_runner.change_test_name("transient")
	var container := InjectionContainer.new(null)
	container.register(_class_registration(TrackedService, Lifecycle.Type.TRANSIENT))
	var first = container.resolve(TrackedService, &"")
	var second = container.resolve(TrackedService, &"")

	_runner.assert_true(not is_same(second, first), "Transientは異なる参照を返す")
	_runner.assert_not_equal(second.instance_id, first.instance_id, "Transientごとに異なるIDを付ける")


func _test_instance_registration() -> void:
	_runner.change_test_name("instance_registration")
	var container := InjectionContainer.new(null)
	var provided := TrackedService.new()
	container.register(ServiceRegistration.create_instance_registration(provided, TrackedService))

	_runner.assert_same(container.resolve(TrackedService, &""), provided, "提供された参照を返す")
	_runner.assert_same(container.resolve(TrackedService, &""), provided, "再解決でも提供された参照を返す")


func _test_invalid_instance_registrations() -> void:
	_runner.change_test_name("invalid_instance_registrations")
	var container := InjectionContainer.new(null)
	var derived := DerivedService.new()
	container.register(ServiceRegistration.create_instance_registration(derived, BaseService))
	_runner.assert_same(container.resolve(BaseService, &""), derived, "指定実装型の派生インスタンスを登録できる")

	var capture := ErrorCapture.new()
	capture.start()
	container.register(ServiceRegistration.create_instance_registration(null, DerivedService))
	container.register(ServiceRegistration.create_instance_registration(
		UnrelatedService.new(),
		DerivedService,
	))
	container.register(ServiceRegistration.create_instance_registration(
		DerivedService.new(),
		DerivedService,
	).as_type(UnrelatedService))
	capture.stop()

	_runner.assert_equal(capture.errors.size(), 3, "null・無関係な実体・公開型不整合をすべて拒否する")
	_runner.assert_true(capture.contains("外部インスタンスに null は指定できません"), "null拒否理由を報告する")
	_runner.assert_true(capture.contains("実際の型="), "型不一致で実際の型を報告する")
	_runner.assert_true(capture.contains("指定された実装型="), "型不一致で指定実装型を報告する")
	_runner.assert_true(capture.contains("公開型="), "型不一致で公開型を報告する")


func _test_key_precedence_and_default_fallback() -> void:
	_runner.change_test_name("key_precedence_and_default_fallback")
	var container := InjectionContainer.new(null)
	var default_service := DerivedService.new()
	var keyed_service := DerivedService.new()
	container.register(_instance_as(default_service, DerivedService, BaseService))
	container.register(_instance_as(keyed_service, DerivedService, BaseService, &"primary"))

	_runner.assert_same(container.resolve(BaseService, &"primary"), keyed_service, "同じキーの登録を優先する")
	_runner.assert_same(container.resolve(BaseService, &"missing"), default_service, "不明なキーはローカルのデフォルトへフォールバックする")


func _test_parent_lookup_order() -> void:
	_runner.change_test_name("parent_lookup_order")
	var parent := InjectionContainer.new(null)
	var child := InjectionContainer.new(parent)
	var parent_default := DerivedService.new()
	var parent_keyed := DerivedService.new()
	var child_default := DerivedService.new()
	parent.register(_instance_as(parent_default, DerivedService, BaseService))
	parent.register(_instance_as(parent_keyed, DerivedService, BaseService, &"primary"))

	_runner.assert_same(child.resolve(BaseService, &"primary"), parent_keyed, "要求キーを維持して親から解決する")
	child.register(_instance_as(child_default, DerivedService, BaseService))
	_runner.assert_same(child.resolve(BaseService, &""), child_default, "子のローカル登録が親の同一登録を上書きする")
	_runner.assert_same(child.resolve(BaseService, &"primary"), parent_keyed, "親のキー付き登録を子のデフォルトより優先する")


func _test_duplicate_registrations() -> void:
	_runner.change_test_name("duplicate_registrations")
	var container := InjectionContainer.new(null)
	var first := DerivedService.new()
	var rejected := DerivedService.new()
	container.register(_instance_as(first, DerivedService, BaseService, &"same"))

	var capture := ErrorCapture.new()
	capture.start()
	var succeeded := container.register(_instance_as(rejected, DerivedService, BaseService, &"same"))
	capture.stop()
	_runner.assert_false(succeeded, "重複登録は失敗を返す")
	_runner.assert_true(capture.contains("登録が重複しています"), "重複登録がpush_errorを発生させる")
	_runner.assert_same(container.resolve(BaseService, &"same"), first, "先に登録したサービスを維持する")


func _test_key_scopes() -> void:
	_runner.change_test_name("key_scopes")
	var container := InjectionContainer.new(null)
	var first := DerivedService.new()
	var second := DerivedService.new()
	var unrelated := UnrelatedService.new()
	container.register(_instance_as(first, DerivedService, BaseService, &"first"))
	container.register(_instance_as(second, DerivedService, BaseService, &"second"))
	container.register(ServiceRegistration.create_instance_registration(unrelated, UnrelatedService).with_key(&"first"))

	_runner.assert_same(container.resolve(BaseService, &"first"), first, "同じ契約型の第一キーを解決する")
	_runner.assert_same(container.resolve(BaseService, &"second"), second, "同じ契約型の異なるキーが併存する")
	_runner.assert_same(container.resolve(UnrelatedService, &"first"), unrelated, "異なる契約型で同じキーを使用する")


func _test_invalid_registration() -> void:
	_runner.change_test_name("invalid_registration")
	var container := InjectionContainer.new(null)
	var invalid := ServiceRegistration.new()
	var capture := ErrorCapture.new()
	capture.start()
	var succeeded := container.register(invalid)
	var result = container.resolve(BaseService, &"")
	capture.stop()

	_runner.assert_true(capture.contains("登録情報が不正です"), "不正登録がpush_errorを発生させる")
	_runner.assert_false(succeeded, "不正登録は失敗を返す")
	_runner.assert_true(capture.contains("登録が見つかりません"), "不正登録のエントリが追加されていない")
	_runner.assert_null(result, "不正登録を解決できない")


func _test_null_registration() -> void:
	_runner.change_test_name("null_registration")
	var container := InjectionContainer.new(null)
	var capture := ErrorCapture.new()
	capture.start()
	var succeeded := container.register(null)
	capture.stop()

	_runner.assert_false(succeeded, "nullの登録は失敗を返す")
	_runner.assert_true(capture.contains("ServiceRegistration に null は指定できません"), "nullの拒否理由を報告する")


func _test_unregistered_service() -> void:
	_runner.change_test_name("unregistered_service")
	var container := InjectionContainer.new(null)
	var capture := ErrorCapture.new()
	capture.start()
	var result = container.resolve(BaseService, &"")
	capture.stop()

	_runner.assert_true(capture.contains("登録が見つかりません"), "未登録解決がpush_errorを発生させる")
	_runner.assert_null(result, "未登録サービスはnullになる")


func _test_clear() -> void:
	_runner.change_test_name("clear")
	var parent := InjectionContainer.new(null)
	var child := InjectionContainer.new(parent)
	parent.register(_class_registration(TrackedService, Lifecycle.Type.SINGLETON))
	child.register(_instance_as(DerivedService.new(), DerivedService, BaseService))
	var singleton = parent.resolve(TrackedService, &"")
	var singleton_weak: WeakRef = weakref(singleton)
	singleton = null
	child.clear()
	parent.clear()

	var capture := ErrorCapture.new()
	capture.start()
	var local_result = child.resolve(BaseService, &"")
	var parent_result = child.resolve(TrackedService, &"")
	capture.stop()
	_runner.assert_null(local_result, "clear後はローカル登録を利用できない")
	_runner.assert_null(parent_result, "clear後は親参照を利用できない")
	_runner.assert_true(capture.errors.size() == 2, "利用不能な各解決がpush_errorを発生させる")
	_runner.assert_null(singleton_weak.get_ref(), "生成済みSingletonへの参照を保持しない")


func _test_empty_and_nonempty_keys_do_not_collide() -> void:
	_runner.change_test_name("empty_and_nonempty_keys_do_not_collide")
	var container := InjectionContainer.new(null)
	var default_service := DerivedService.new()
	var keyed_service := DerivedService.new()
	container.register(_instance_as(default_service, DerivedService, BaseService))
	container.register(_instance_as(keyed_service, DerivedService, BaseService, &"TestBaseService"))

	_runner.assert_same(container.resolve(BaseService, &""), default_service, "空IDの登録を独立して解決する")
	_runner.assert_same(container.resolve(BaseService, &"TestBaseService"), keyed_service, "通常IDの登録を独立して解決する")


func _class_registration(type: Script, lifecycle: Lifecycle.Type) -> ServiceRegistration:
	return ServiceRegistration.create_class_registration(type, lifecycle)


func _instance_as(
	instance: Variant,
	implementation: Script,
	service: Script,
	key: StringName = &"",
) -> ServiceRegistration:
	return ServiceRegistration.create_instance_registration(instance, implementation).as_type(service).with_key(key)
