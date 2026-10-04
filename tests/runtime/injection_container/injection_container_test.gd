extends SceneTree


const BaseService := preload("fixtures/services/base_service.gd")
const DerivedService := preload("fixtures/services/derived_service.gd")
const UnrelatedService := preload("fixtures/services/unrelated_service.gd")

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_default_resolution()
	_test_registration_error_state_transitions()
	_test_registration_settings_are_independent()
	_test_freed_registration_does_not_fallback()
	_test_key_precedence_and_default_fallback()
	_test_parent_lookup_order()
	_test_rejected_registrations()
	_test_duplicate_registrations()
	_test_key_scopes()
	_test_unregistered_service()
	_test_clear()
	_test_empty_and_nonempty_keys_do_not_collide()

	await _runner.finish(self, "InjectionContainer")


## キーを指定しないサービス登録を既定のキーで解決できることを確認します。
func _test_default_resolution() -> void:
	_runner.change_test_name("default_resolution")
	var container := InjectionContainer.new(null)
	var provided := DerivedService.new()
	var succeeded := container.register(
			ServiceRegistration.create_instance_registration(provided)
	)

	var resolved = container.resolve(DerivedService, &"")
	_runner.assert_true(succeeded, "正常な登録は成功を返す")
	_runner.assert_same(resolved, provided, "Scriptからデフォルト登録を解決する")
	_runner.assert_same(container.resolve(DerivedService, &""), provided, "再解決でも同じ参照を返す")
	provided.free()


## 登録失敗後も既存サービスを維持し、後続の正常登録でエラー状態を解除しない。
func _test_registration_error_state_transitions() -> void:
	_runner.change_test_name("registration_error_state_transitions")
	var container := InjectionContainer.new(null)
	_runner.assert_false(container.has_registration_errors, "新規コンテナには登録エラーがない")

	var first := DerivedService.new()
	container.register(_instance_as(first, BaseService, &"first"))
	_runner.assert_false(container.has_registration_errors, "正常登録では登録エラー状態を変更しない")

	var invalid_succeeded := container.register(ServiceRegistration.new())
	_runner.assert_false(invalid_succeeded, "不正登録は失敗を返す")
	_runner.assert_true(container.has_registration_errors, "不正登録で登録エラー状態になる")

	var duplicate := DerivedService.new()
	var duplicate_succeeded := container.register(_instance_as(duplicate, BaseService, &"first"))
	_runner.assert_false(duplicate_succeeded, "重複登録は失敗を返す")
	_runner.assert_true(container.has_registration_errors, "重複登録後も登録エラー状態である")

	var after_failure := DerivedService.new()
	var succeeded := container.register(_instance_as(after_failure, BaseService, &"after_failure"))
	_runner.assert_true(succeeded, "失敗後でも別の正常な登録は成功する")
	_runner.assert_true(container.has_registration_errors, "後続の正常登録は累積エラー状態を解除しない")
	_runner.assert_same(
			container.resolve(BaseService, &"first"),
			first,
			"登録失敗後も既存の正常な登録を維持する",
	)
	first.free()
	duplicate.free()
	after_failure.free()


## 登録後の設定変更は、登録済みの型・キー・Node参照に影響しません。
func _test_registration_settings_are_independent() -> void:
	_runner.change_test_name("registration_settings_are_independent")
	var container := InjectionContainer.new(null)
	var original := DerivedService.new()
	var replacement := UnrelatedService.new()
	var registration := _instance_as(original, BaseService, &"original")
	container.register(registration)
	registration.instance = replacement
	registration.as_type(UnrelatedService).with_key(&"replacement")
	_runner.assert_same(container.resolve(BaseService, &"original"), original, "設定変更後も登録時のNodeを返す")
	_runner.assert_true(container.register(registration), "変更した設定は新しい登録に使用できる")
	_runner.assert_same(container.resolve(UnrelatedService, &"replacement"), replacement, "再登録では変更後の設定を使う")
	original.free()
	replacement.free()


## 解放済みの登録も存在し、祖先や既定キーへのフォールバックを抑止します。
func _test_freed_registration_does_not_fallback() -> void:
	_runner.change_test_name("freed_registration_does_not_fallback")
	var parent := InjectionContainer.new(null)
	var child := InjectionContainer.new(parent)
	var fallback := DerivedService.new()
	var freed := DerivedService.new()
	parent.register(_instance_as(fallback, BaseService, &"primary"))
	child.register(_instance_as(fallback, BaseService))
	child.register(_instance_as(freed, BaseService, &"primary"))
	freed.free()
	var capture := ErrorCapture.new()
	capture.start()
	var result = child.resolve(BaseService, &"primary")
	capture.stop()
	_runner.assert_false(is_instance_valid(result), "解放済みNodeを別の登録に置き換えない")
	_runner.assert_equal(capture.errors.size(), 0, "解放済み登録を未登録エラーにしない")
	fallback.free()


## 指定キーの登録を優先し、見つからない場合は既定キーの登録へフォールバックすることを確認します。
func _test_key_precedence_and_default_fallback() -> void:
	_runner.change_test_name("key_precedence_and_default_fallback")
	var container := InjectionContainer.new(null)
	var default_service := DerivedService.new()
	var keyed_service := DerivedService.new()
	container.register(_instance_as(default_service,  BaseService))
	container.register(_instance_as(keyed_service, BaseService, &"primary"))

	_runner.assert_same(container.resolve(BaseService, &"primary"), keyed_service, "同じキーの登録を優先する")
	_runner.assert_same(container.resolve(BaseService, &"missing"), default_service, "不明なキーはローカルのデフォルトへフォールバックする")
	default_service.free()
	keyed_service.free()


## 現在のコンテナで見つからないサービスを親コンテナから解決できることを確認します。
func _test_parent_lookup_order() -> void:
	_runner.change_test_name("parent_lookup_order")
	var parent := InjectionContainer.new(null)
	var child := InjectionContainer.new(parent)
	var parent_default := DerivedService.new()
	var parent_keyed := DerivedService.new()
	var child_default := DerivedService.new()
	parent.register(_instance_as(parent_default, BaseService))
	parent.register(_instance_as(parent_keyed, BaseService, &"primary"))

	_runner.assert_same(child.resolve(BaseService, &"primary"), parent_keyed, "要求キーを維持して親から解決する")
	child.register(_instance_as(child_default, BaseService))
	_runner.assert_same(child.resolve(BaseService, &""), child_default, "子のローカル登録が親の同一登録を上書きする")
	_runner.assert_same(child.resolve(BaseService, &"primary"), parent_keyed, "親のキー付き登録を子のデフォルトより優先する")
	parent_default.free()
	parent_keyed.free()
	child_default.free()


## 不正登録の詳細はValidatorで検証し、ここでは拒否と状態への反映を確認する。
func _test_rejected_registrations() -> void:
	var incompatible := DerivedService.new()
	var scriptless := Node.new()
	var cases := [
		["null_registration", null],
		["empty_registration", ServiceRegistration.new()],
		["null_instance", ServiceRegistration.create_instance_registration(null)],
		["missing_script", ServiceRegistration.create_instance_registration(scriptless)],
		["incompatible_type", _instance_as(incompatible, UnrelatedService)],
	]
	for test_case in cases:
		_runner.change_test_name(test_case[0])
		var container := InjectionContainer.new(null)
		_runner.assert_false(container.register(test_case[1]), "不正な登録を拒否する")
		_runner.assert_true(container.has_registration_errors, "登録失敗を状態へ反映する")
	incompatible.free()
	scriptless.free()


## 同じ型とキーの重複登録を拒否し、先に登録したサービスを維持することを確認します。
func _test_duplicate_registrations() -> void:
	_runner.change_test_name("duplicate_registrations")
	var container := InjectionContainer.new(null)
	var first := DerivedService.new()
	var rejected := DerivedService.new()
	container.register(_instance_as(first, BaseService, &"same"))

	var capture := ErrorCapture.new()
	capture.start()
	var succeeded := container.register(_instance_as(rejected, BaseService, &"same"))
	capture.stop()
	_runner.assert_false(succeeded, "重複登録は失敗を返す")
	_runner.assert_true(container.has_registration_errors, "重複登録を累積エラー状態へ反映する")
	_runner.assert_equal(capture.errors.size(), 1, "重複登録が一度だけpush_errorを発生させる")
	_runner.assert_same(container.resolve(BaseService, &"same"), first, "先に登録したサービスを維持する")
	first.free()
	rejected.free()


## 同じサービス型でもキーごとに独立した登録として解決できることを確認します。
func _test_key_scopes() -> void:
	_runner.change_test_name("key_scopes")
	var container := InjectionContainer.new(null)
	var first := DerivedService.new()
	var second := DerivedService.new()
	var unrelated := UnrelatedService.new()
	container.register(_instance_as(first,  BaseService, &"first"))
	container.register(_instance_as(second, BaseService, &"second"))
	container.register(ServiceRegistration.create_instance_registration(unrelated).with_key(&"first"))

	_runner.assert_same(container.resolve(BaseService, &"first"), first, "同じ契約型の第一キーを解決する")
	_runner.assert_same(container.resolve(BaseService, &"second"), second, "同じ契約型の異なるキーが併存する")
	_runner.assert_same(container.resolve(UnrelatedService, &"first"), unrelated, "異なる契約型で同じキーを使用する")
	first.free()
	second.free()
	unrelated.free()


## 未登録のサービスを解決したとき、nullを返してエラーを報告することを確認します。
func _test_unregistered_service() -> void:
	_runner.change_test_name("unregistered_service")
	var container := InjectionContainer.new(null)
	var capture := ErrorCapture.new()
	capture.start()
	var result = container.resolve(BaseService, &"")
	capture.stop()

	_runner.assert_equal(capture.errors.size(), 1, "未登録解決が一度だけpush_errorを発生させる")
	_runner.assert_null(result, "未登録サービスはnullになる")


## clearで登録と親参照だけを解除し、取得済み参照を維持することを確認します。
func _test_clear() -> void:
	_runner.change_test_name("clear")
	var parent := InjectionContainer.new(null)
	var child := InjectionContainer.new(parent)
	var parent_service := DerivedService.new()
	parent.register(ServiceRegistration.create_instance_registration(parent_service))
	var child_service := DerivedService.new()
	child.register(_instance_as(child_service, BaseService))
	var retained = child.resolve(BaseService, &"")
	child.clear()

	var local_result = child.resolve(BaseService, &"")
	var parent_result = child.resolve(DerivedService, &"")
	_runner.assert_null(local_result, "clear後はローカル登録を利用できない")
	_runner.assert_null(parent_result, "clear後は親参照を利用できない")
	_runner.assert_same(retained, child_service, "clear後も取得済みのNode参照を維持する")
	_runner.assert_true(is_instance_valid(retained), "clearでNode自体は破棄しない")
	_runner.assert_same(parent.resolve(DerivedService, &""), parent_service, "親コンテナの登録は維持する")
	_runner.assert_true(child.register(_instance_as(child_service, BaseService)), "clear後に再登録できる")
	_runner.assert_same(child.resolve(BaseService, &""), child_service, "再登録後はNodeを解決できる")
	parent_service.free()
	child_service.free()


## 空キーと文字列キーの登録が衝突せず、それぞれ対応するサービスを解決することを確認します。
func _test_empty_and_nonempty_keys_do_not_collide() -> void:
	_runner.change_test_name("empty_and_nonempty_keys_do_not_collide")
	var container := InjectionContainer.new(null)
	var default_service := DerivedService.new()
	var keyed_service := DerivedService.new()
	container.register(_instance_as(default_service, BaseService))
	container.register(_instance_as(keyed_service, BaseService, &"TestBaseService"))

	_runner.assert_same(container.resolve(BaseService, &""), default_service, "空IDの登録を独立して解決する")
	_runner.assert_same(container.resolve(BaseService, &"TestBaseService"), keyed_service, "通常IDの登録を独立して解決する")
	default_service.free()
	keyed_service.free()


func _instance_as(
		instance: Node,
		service: Script,
		key: StringName = &"",
) -> ServiceRegistration:
	return ServiceRegistration.create_instance_registration(instance).as_type(service).with_key(key)
