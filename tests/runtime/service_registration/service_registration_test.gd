extends SceneTree


const BaseService := preload("fixtures/services/base_service.gd")
const DerivedService := preload("fixtures/services/derived_service.gd")
const UnrelatedService := preload("fixtures/services/unrelated_service.gd")
const UnnamedService := preload("fixtures/services/unnamed_service.gd")
const RegistrationValidator := preload(
		"res://addons/katamusubi/runtime/container/service_registration_validator.gd"
)

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_create_instance_registration()
	_test_dedicated_validator()
	_test_validation_codes()
	_test_fluent_updates()
	_test_unnamed_type()
	_test_valid_registration()
	_test_error_formatting()

	await _runner.finish(self, "ServiceRegistration")


## 外部生成したインスタンスを同じ参照のまま登録することを確認します。
func _test_create_instance_registration() -> void:
	_runner.change_test_name("create_instance_registration")
	var provided_instance := DerivedService.new()
	var registration := ServiceRegistration.create_instance_registration(provided_instance)

	_runner.assert_same(registration.instance, provided_instance, "渡されたインスタンスそのものを保持する")
	_expect(registration.implementation_type == DerivedService, "インスタンス登録に実装型を設定する")
	_expect(registration.service_type == DerivedService, "インスタンス登録は実装型自身を公開する")
	provided_instance.free()


## 専用バリデーターとServiceRegistrationのAPIが同じコードを返すことを確認します。
func _test_dedicated_validator() -> void:
	_runner.change_test_name("dedicated_validator")
	var registration := ServiceRegistration.new()
	var validator_code := RegistrationValidator.validate(registration)

	_runner.assert_equal(
			validator_code,
			RegistrationValidator.ErrorCode.NULL_INSTANCE,
			"空の登録は検証順序上最初のインスタンス欠落を返す",
	)
	_runner.assert_equal(
			registration.validate(),
			validator_code,
			"ServiceRegistration.validateは専用バリデーターへ委譲する",
	)
	_runner.assert_equal(
			RegistrationValidator.validate(null),
			RegistrationValidator.ErrorCode.NULL_REGISTRATION,
			"専用バリデーターがnull登録を安全に拒否する",
	)


## 検証順序の各段階に対応する入力が、それぞれ固有のコードを返すことを確認します。
func _test_validation_codes() -> void:
	_runner.change_test_name("validation_codes")

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

	var missing_implementation := _valid_registration()
	missing_implementation.implementation_type = null
	_expect_validation_code(
			missing_implementation,
			RegistrationValidator.ErrorCode.MISSING_IMPLEMENTATION_TYPE,
			"実装型欠落",
	)
	missing_implementation.instance.free()

	var incompatible_implementation := _valid_registration()
	incompatible_implementation.implementation_type = UnrelatedService
	incompatible_implementation.service_type = UnrelatedService
	_expect_validation_code(
			incompatible_implementation,
			RegistrationValidator.ErrorCode.INCOMPATIBLE_IMPLEMENTATION_TYPE,
			"登録インスタンスと実装型の不一致",
	)
	incompatible_implementation.instance.free()

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
	incompatible_service.instance.free()


## fluent APIが新しい登録を生成せず、同じ登録の公開型とキーを更新することを確認します。
func _test_fluent_updates() -> void:
	_runner.change_test_name("fluent_updates")
	var registration := ServiceRegistration.create_instance_registration(DerivedService.new())
	var as_type_result = registration.as_type(BaseService)
	var with_key_result = registration.with_key(&"primary")

	_runner.assert_same(as_type_result, registration, "as_typeは同一登録オブジェクトを返す")
	_expect(registration.service_type == BaseService, "as_typeは公開型を更新する")
	_runner.assert_same(with_key_result, registration, "with_keyは同一登録オブジェクトを返す")
	_expect(registration.key == &"primary", "with_keyは登録キーを更新する")
	registration.instance.free()


## グローバルクラス名を持たないScriptも正常なサービス型として登録できることを確認します。
func _test_unnamed_type() -> void:
	_runner.change_test_name("unnamed_type")
	var registration := ServiceRegistration.create_instance_registration(UnnamedService.new())

	_runner.assert_equal(
			registration.validate(),
			RegistrationValidator.ErrorCode.OK,
			"class_nameのないScriptを正常な登録として扱う",
	)
	registration.instance.free()


## 型と継承関係が正しいサービス登録が成功コードを返すことを確認します。
func _test_valid_registration() -> void:
	_runner.change_test_name("valid_registration")
	var registration := _valid_registration()
	_runner.assert_equal(
			registration.validate(),
			RegistrationValidator.ErrorCode.OK,
			"派生実装を基底型として公開できる",
	)
	registration.instance.free()


## 説明文の整形が検証から独立し、診断に必要な情報だけを安全に含むことを確認します。
func _test_error_formatting() -> void:
	_runner.change_test_name("error_formatting")
	_runner.assert_equal(
			RegistrationValidator.format_error(RegistrationValidator.ErrorCode.OK, null),
			"",
			"OKは説明文を持たない",
	)

	var null_message := RegistrationValidator.format_error(
			RegistrationValidator.ErrorCode.NULL_REGISTRATION,
			null,
	)
	_runner.assert_false(null_message.is_empty(), "null登録の説明文を生成できる")
	var null_instance_message := RegistrationValidator.format_error(
			RegistrationValidator.ErrorCode.NULL_INSTANCE,
			ServiceRegistration.new(),
	)
	_runner.assert_false(null_instance_message.is_empty(), "nullインスタンスの説明文を生成できる")

	var freed_node := Node.new()
	var freed_registration := ServiceRegistration.new()
	freed_registration.instance = freed_node
	freed_node.free()
	var invalid_message := RegistrationValidator.format_error(
			RegistrationValidator.ErrorCode.INVALID_INSTANCE,
			freed_registration,
	)
	_runner.assert_false(invalid_message.is_empty(), "解放済みインスタンスの説明文を安全に生成できる")

	var incompatible_implementation := _valid_registration()
	incompatible_implementation.implementation_type = UnrelatedService
	var implementation_message := RegistrationValidator.format_error(
			RegistrationValidator.ErrorCode.INCOMPATIBLE_IMPLEMENTATION_TYPE,
			incompatible_implementation,
	)
	var actual_type: Script = incompatible_implementation.instance.get_script()
	_expect(actual_type.get_global_name() in implementation_message, "実装型不適合に実際の型名を含める")
	_expect(
			incompatible_implementation.implementation_type.get_global_name() in implementation_message,
			"実装型不適合に指定実装型名を含める",
	)
	incompatible_implementation.instance.free()

	var incompatible_service := ServiceRegistration.create_instance_registration(
			UnrelatedService.new(),
	).as_type(BaseService)
	var service_message := RegistrationValidator.format_error(
			RegistrationValidator.ErrorCode.INCOMPATIBLE_SERVICE_TYPE,
			incompatible_service,
	)
	_expect(incompatible_service.implementation_type.get_global_name() in service_message, "公開型不適合に実装型名を含める")
	_expect(incompatible_service.service_type.get_global_name() in service_message, "公開型不適合に公開型名を含める")
	incompatible_service.instance.free()

	var unnamed_registration := ServiceRegistration.create_instance_registration(UnnamedService.new())
	unnamed_registration.implementation_type = UnrelatedService
	var unnamed_message := RegistrationValidator.format_error(
			RegistrationValidator.ErrorCode.INCOMPATIBLE_IMPLEMENTATION_TYPE,
			unnamed_registration,
	)
	var unnamed_type: Script = unnamed_registration.instance.get_script()
	_expect(unnamed_type.resource_path in unnamed_message, "class_nameのない型をScriptパスで識別する")
	unnamed_registration.instance.free()


func _valid_registration() -> ServiceRegistration:
	return ServiceRegistration.create_instance_registration(
			DerivedService.new(),
	).as_type(BaseService).with_key(&"fixture")


func _expect_validation_code(
		registration: ServiceRegistration,
		expected_code: RegistrationValidator.ErrorCode,
		message: String,
) -> void:
	_runner.assert_equal(registration.validate(), expected_code, message)


func _expect(condition: bool, message: String) -> void:
	_runner.assert_true(condition, message)
