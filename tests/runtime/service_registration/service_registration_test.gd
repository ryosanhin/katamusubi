extends SceneTree


const BaseService := preload("fixtures/services/base_service.gd")
const DerivedService := preload("fixtures/services/derived_service.gd")
const UnrelatedService := preload("fixtures/services/unrelated_service.gd")
const RegistrationValidator := preload(
		"res://addons/katamusubi/runtime/registration//service_registration_validator.gd"
)

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_create_instance_registration()
	_test_validation_codes()
	_test_fluent_updates()
	_test_valid_registration()
	_test_error_formatting()

	await _runner.finish(self, "ServiceRegistration")


## 外部生成したインスタンスを同じ参照のまま登録することを確認します。
func _test_create_instance_registration() -> void:
	_runner.change_test_name("create_instance_registration")
	var provided_instance := DerivedService.new()
	var registration := ServiceRegistration.create_instance_registration(provided_instance)

	_runner.assert_same(registration.instance, provided_instance, "渡されたインスタンスそのものを保持する")
	_runner.assert_true(registration.service_type == DerivedService, "インスタンス登録は実装型自身を公開する")
	provided_instance.free()


## 検証順序の各段階に対応する入力が、それぞれ固有のコードを返すことを確認します。
func _test_validation_codes() -> void:
	_runner.change_test_name("validation_codes")

	_expect_validation_code(
			null,
			RegistrationValidator.ErrorCode.NULL_REGISTRATION,
			"null登録",
	)

	_expect_validation_code(
			ServiceRegistration.create_instance_registration(null),
			RegistrationValidator.ErrorCode.NULL_INSTANCE,
			"nullインスタンス",
	)

	var freed_node := Node.new()
	var freed_registration := ServiceRegistration.new()
	freed_registration.instance = freed_node
	freed_node.free()
	_expect_validation_code(
			freed_registration,
			RegistrationValidator.ErrorCode.NULL_INSTANCE,
			"Godotがnullとして扱う解放済みインスタンス",
	)

	var missing_script := ServiceRegistration.new()
	missing_script.instance = Node.new()
	_expect_validation_code(
			missing_script,
			RegistrationValidator.ErrorCode.MISSING_SCRIPT,
			"Scriptなしインスタンス",
	)
	missing_script.instance.free()

	var missing_service := _valid_registration()
	missing_service.service_type = null
	_expect_validation_code(
			missing_service,
			RegistrationValidator.ErrorCode.MISSING_SERVICE_TYPE,
			"公開型欠落",
	)
	missing_service.instance.free()

	var incompatible_service := ServiceRegistration.create_instance_registration(
			UnrelatedService.new(),
	).as_type(BaseService)
	_expect_validation_code(
			incompatible_service,
			RegistrationValidator.ErrorCode.INCOMPATIBLE_SERVICE_TYPE,
			"実装型と公開型の不一致",
	)
	var incompatible_result := RegistrationValidator.validate(incompatible_service)
	var unrelated_script: Script = UnrelatedService
	_runner.assert_equal(
			unrelated_script.get_global_name(),
			incompatible_result.actual_type_name,
			"実装型名を保持する",
	)
	var base_script: Script = BaseService
	_runner.assert_equal(
			base_script.get_global_name(),
			incompatible_result.service_type_name,
			"公開型名を保持する",
	)
	incompatible_service.instance.free()


## fluent APIが新しい登録を生成せず、同じ登録の公開型とキーを更新することを確認します。
func _test_fluent_updates() -> void:
	_runner.change_test_name("fluent_updates")
	var registration := ServiceRegistration.create_instance_registration(DerivedService.new())
	var as_type_result = registration.as_type(BaseService)
	var with_key_result = registration.with_key(&"primary")

	_runner.assert_same(as_type_result, registration, "as_typeは同一登録オブジェクトを返す")
	_runner.assert_true(registration.service_type == BaseService, "as_typeは公開型を更新する")
	_runner.assert_same(with_key_result, registration, "with_keyは同一登録オブジェクトを返す")
	_runner.assert_true(registration.key == &"primary", "with_keyは登録キーを更新する")
	registration.instance.free()


## 型と継承関係が正しいサービス登録が成功コードを返すことを確認します。
func _test_valid_registration() -> void:
	_runner.change_test_name("valid_registration")
	var registration := _valid_registration()
	var result := RegistrationValidator.validate(registration)
	_runner.assert_true(result.is_valid(),"派生実装を基底型として公開できる")
	registration.instance.free()


## 説明文の整形が検証から独立し、診断に必要な情報だけを安全に含むことを確認します。
func _test_error_formatting() -> void:
	_runner.change_test_name("error_formatting")
	var result := RegistrationValidator.ValidationResult.new()
	_runner.assert_equal(
			RegistrationValidator.format_error(result),
			"",
			"OKは説明文を持たない",
	)

	result.error_code = RegistrationValidator.ErrorCode.INCOMPATIBLE_SERVICE_TYPE
	result.actual_type_name = &"actual_type_name"
	result.service_type_name = &"service_type_name"
	var incompatible_massage := RegistrationValidator.format_error(result)
	_runner.assert_true(
			"actual_type_name" in incompatible_massage,
			"公開型不適合に実際の型名を含める",
	)
	_runner.assert_true(
			"service_type_name" in incompatible_massage,
			"公開型不適合に公開型名を含める",
	)


func _valid_registration() -> ServiceRegistration:
	return ServiceRegistration.create_instance_registration(
			DerivedService.new(),
	).as_type(BaseService).with_key(&"fixture")


func _expect_validation_code(
		registration: ServiceRegistration,
		expected_code: RegistrationValidator.ErrorCode,
		message: String,
) -> void:
	var result := RegistrationValidator.validate(registration)
	_runner.assert_equal(
			result.error_code,
			expected_code,
			message,
	)
