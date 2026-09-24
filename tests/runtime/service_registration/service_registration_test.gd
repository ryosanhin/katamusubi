extends SceneTree


const BaseService := preload("fixtures/services/base_service.gd")
const DerivedService := preload("fixtures/services/derived_service.gd")
const UnrelatedService := preload("fixtures/services/unrelated_service.gd")
const UnnamedService := preload("fixtures/services/unnamed_service.gd")
const RegistrationValidator := preload(
		"res://addons/katamusubi/runtime/container/service_registration_validator.gd"
)
const ValidationError := preload(
		"res://addons/katamusubi/runtime/container/service_registration_validation_error.gd"
)

var _runner := TestRunner.new(true)


func _init() -> void:
	# 公開APIの生成・更新、継承判定、検証の各ケースを順番に確認します。
	_test_create_instance_registration()
	_test_dedicated_validator()
	_test_instance_validation()
	_test_fluent_updates()
	_test_missing_types()
	_test_unnamed_type()
	_test_unrelated_registration()
	_test_valid_registration()

	await _runner.finish(self, "ServiceRegistration")


## 外部生成したインスタンスを同じ参照のまま登録することを確認します。
func _test_create_instance_registration() -> void:
	_runner.change_test_name("create_instance_registration")
	# 外部生成した同じインスタンスを保持します。
	var provided_instance := DerivedService.new()
	var registration := ServiceRegistration.create_instance_registration(provided_instance)

	_runner.assert_same(registration.instance, provided_instance, "渡されたインスタンスそのものを保持する")
	_expect(registration.implementation_type == DerivedService, "インスタンス登録に実装型を設定する")
	_expect(registration.service_type == DerivedService, "インスタンス登録は実装型自身を公開する")


## 専用バリデーターが登録を検証し、従来APIも同じ結果へ委譲することを確認します。
func _test_dedicated_validator() -> void:
	_runner.change_test_name("dedicated_validator")
	var registration := ServiceRegistration.new()
	var validator_errors := RegistrationValidator.validate_structured(registration)

	_assert_error_codes(
			validator_errors,
			[ValidationError.Code.NULL_INSTANCE],
			"専用バリデーターが不正な登録を検出する",
	)
	_runner.assert_equal(
			registration.validate(),
			PackedStringArray([validator_errors[0].message]),
			"ServiceRegistration.validateは構造化結果の表示文言を返す",
	)
	_assert_error_codes(
			RegistrationValidator.validate_structured(null),
			[ValidationError.Code.NULL_REGISTRATION],
			"専用バリデーターがnull登録を安全に拒否する",
	)


## 外部インスタンスと実装型・公開型の継承関係を検証し、不正な値を報告することを確認します。
func _test_instance_validation() -> void:
	_runner.change_test_name("instance_validation")
	# 実インスタンス自身の継承関係を、指定された実装型と公開型の両方に対して検証します。
	var derived_as_base := ServiceRegistration.create_instance_registration(DerivedService.new())
	_expect(derived_as_base.validate().is_empty(), "指定実装型の派生インスタンスを許可する")

	var unrelated := ServiceRegistration.create_instance_registration(
			UnrelatedService.new(),
	).as_type(BaseService)
	unrelated.implementation_type = DerivedService
	_expect_validation_error(unrelated, ValidationError.Code.INCOMPATIBLE_IMPLEMENTATION_TYPE)

	var null_instance := ServiceRegistration.create_instance_registration(null)
	_expect_validation_error(null_instance, ValidationError.Code.NULL_INSTANCE)
	var non_object := ServiceRegistration.create_instance_registration(42)
	_expect_validation_error(non_object, ValidationError.Code.INVALID_INSTANCE)
	var object_without_script := ServiceRegistration.create_instance_registration(RefCounted.new())
	_expect_validation_error(object_without_script, ValidationError.Code.MISSING_INSTANCE_SCRIPT)

	var incompatible_service := ServiceRegistration.create_instance_registration(
			DerivedService.new(),
	).as_type(UnrelatedService)
	_expect_validation_error(incompatible_service, ValidationError.Code.INCOMPATIBLE_SERVICE_TYPE)


## fluent APIが新しい登録を生成せず、同じ登録の公開型とキーを更新することを確認します。
func _test_fluent_updates() -> void:
	_runner.change_test_name("fluent_updates")
	# fluent APIは新しい登録を作らず、同一オブジェクトの公開型とキーを更新します。
	var registration := ServiceRegistration.create_instance_registration(DerivedService.new())
	var as_type_result = registration.as_type(BaseService)
	var with_key_result = registration.with_key(&"primary")

	_runner.assert_same(as_type_result, registration, "as_typeは同一登録オブジェクトを返す")
	_expect(registration.service_type == BaseService, "as_typeは公開型を更新する")
	_expect(with_key_result == registration, "with_keyは同一登録オブジェクトを返す")
	_expect(registration.key == &"primary", "with_keyは登録キーを更新する")


## 必須型の欠落が検証エラーとして報告されることを確認します。
func _test_missing_types() -> void:
	_runner.change_test_name("missing_types")
	# 必須型の欠落を検証エラーとして報告します。
	var missing_implementation := _valid_registration()
	missing_implementation.implementation_type = null
	_expect_validation_error(missing_implementation, ValidationError.Code.MISSING_IMPLEMENTATION_TYPE)

	var missing_service := _valid_registration()
	missing_service.service_type = null
	_expect_validation_error(missing_service, ValidationError.Code.MISSING_SERVICE_TYPE)


## グローバルクラス名を持たないScriptも正常なサービス型として登録できることを確認します。
func _test_unnamed_type() -> void:
	_runner.change_test_name("unnamed_type")
	# Scriptそのものを解決キーに使うため、グローバルクラス名がない型も登録できます。
	var registration := ServiceRegistration.create_instance_registration(UnnamedService.new())
	var errors: PackedStringArray = registration.validate()

	_expect(errors.is_empty(), "class_nameのないScriptを正常な登録として扱う")


## 公開型を継承していない実装型の組み合わせが検証エラーになることを確認します。
func _test_unrelated_registration() -> void:
	_runner.change_test_name("unrelated_registration")
	# 実装型が公開型を継承していない組み合わせを検証エラーとして報告します。
	var registration := ServiceRegistration.create_instance_registration(
			UnrelatedService.new(),
	).as_type(BaseService)

	_expect_validation_error(registration, ValidationError.Code.INCOMPATIBLE_SERVICE_TYPE)


## 型と継承関係が正しいサービス登録では検証エラーがないことを確認します。
func _test_valid_registration() -> void:
	_runner.change_test_name("valid_registration")
	# class_nameと継承関係が正しい登録には検証エラーがありません。
	var registration := _valid_registration()
	var errors: PackedStringArray = registration.validate()

	_expect(errors.is_empty(), "正常な登録のエラー配列が空になる")


func _valid_registration() -> ServiceRegistration:
	# 各異常系テストの開始点となる、派生実装を基底型として公開する正常な登録です。
	return ServiceRegistration.create_instance_registration(
			DerivedService.new(),
	).as_type(BaseService).with_key(&"fixture")


func _expect_validation_error(
		registration: ServiceRegistration,
		expected_code: ServiceRegistrationValidationError.Code,
) -> void:
	# 表示文言ではなく、安定したコードで期待する検証エラーを確認します。
	var errors := RegistrationValidator.validate_structured(registration)
	_assert_error_codes(errors, [expected_code], "想定した検証エラーだけを返す")


func _assert_error_codes(
		errors: Array[ServiceRegistrationValidationError],
		expected_codes: Array,
		message: String,
) -> void:
	var actual_codes: Array = errors.map(
			func(error: ServiceRegistrationValidationError) -> int: return error.code,
	)

	_runner.assert_false(errors.is_empty(), "%s: 検証エラーを返す" % message)
	_runner.assert_equal(actual_codes, expected_codes, message)


func _expect(condition: bool, message: String) -> void:
	_runner.assert_true(condition, message)
