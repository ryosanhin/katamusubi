extends SceneTree


const BaseService := preload("fixtures/services/base_service.gd")
const DerivedService := preload("fixtures/services/derived_service.gd")
const UnrelatedService := preload("fixtures/services/unrelated_service.gd")
const UnnamedService := preload("fixtures/services/unnamed_service.gd")

var _runner := TestRunner.new(true)


func _init() -> void:
	# 公開APIの生成・更新、継承判定、検証、Lifecycleの全ケースを順番に確認します。
	_test_create_class_registration()
	_test_create_instance_registration()
	_test_instance_validation()
	_test_fluent_updates()
	_test_missing_types_and_invalid_lifecycle()
	_test_unnamed_type()
	_test_unrelated_registration()
	_test_valid_registration()
	_test_lifecycle_helpers()

	await _runner.finish(self, "ServiceRegistration")


func _test_create_class_registration() -> void:
	_runner.change_test_name("create_class_registration")
	# クラス登録の生成時に実装型と公開型が一致し、指定した生成規則が保存されます。
	var registration := ServiceRegistration.create_class_registration(
		DerivedService,
		Lifecycle.Type.TRANSIENT,
	)

	_expect(registration.implementation_type == DerivedService, "クラス登録に実装型を設定する")
	_expect(registration.service_type == DerivedService, "クラス登録は実装型自身を公開する")
	_expect(registration.lifecycle == Lifecycle.Type.TRANSIENT, "指定したライフサイクルを設定する")


func _test_create_instance_registration() -> void:
	_runner.change_test_name("create_instance_registration")
	# 外部生成した同じインスタンスを保持し、指定にかかわらずSingletonとして登録します。
	var provided_instance := DerivedService.new()
	var registration := ServiceRegistration.create_instance_registration(
		provided_instance,
		DerivedService,
	)

	_runner.assert_same(registration.instance, provided_instance, "渡されたインスタンスそのものを保持する")
	_expect(registration.implementation_type == DerivedService, "インスタンス登録に実装型を設定する")
	_expect(registration.service_type == DerivedService, "インスタンス登録は実装型自身を公開する")
	_expect(registration.lifecycle == Lifecycle.Type.SINGLETON, "インスタンスをSingleton登録する")


func _test_instance_validation() -> void:
	_runner.change_test_name("instance_validation")
	# 実インスタンス自身の継承関係を、指定された実装型と公開型の両方に対して検証します。
	var derived_as_base := ServiceRegistration.create_instance_registration(
		DerivedService.new(),
		BaseService,
	)
	_expect(derived_as_base.validate().is_empty(), "指定実装型の派生インスタンスを許可する")

	var unrelated := ServiceRegistration.create_instance_registration(
		UnrelatedService.new(),
		DerivedService,
	).as_type(BaseService)
	_expect_validation_error(unrelated, "実際の型=ServiceRegistrationTestUnrelatedService")
	_expect_validation_error(unrelated, "指定された実装型=ServiceRegistrationTestDerivedService")
	_expect_validation_error(unrelated, "公開型=ServiceRegistrationTestBaseService")

	var null_instance := ServiceRegistration.create_instance_registration(null, DerivedService)
	_expect_validation_error(null_instance, "外部インスタンスに null は指定できません")
	var non_object := ServiceRegistration.create_instance_registration(42, DerivedService)
	_expect_validation_error(non_object, "外部インスタンスが有効な Object ではありません")
	var object_without_script := ServiceRegistration.create_instance_registration(
		RefCounted.new(),
		DerivedService,
	)
	_expect_validation_error(object_without_script, "外部インスタンスにスクリプトがアタッチされていません")

	var incompatible_service := ServiceRegistration.create_instance_registration(
		DerivedService.new(),
		DerivedService,
	).as_type(UnrelatedService)
	_expect_validation_error(incompatible_service, "公開型=ServiceRegistrationTestUnrelatedService")


func _test_fluent_updates() -> void:
	_runner.change_test_name("fluent_updates")
	# fluent APIは新しい登録を作らず、同一オブジェクトの公開型とキーを更新します。
	var registration := ServiceRegistration.create_class_registration(
		DerivedService,
		Lifecycle.Type.TRANSIENT,
	)
	var as_type_result = registration.as_type(BaseService)
	var with_key_result = registration.with_key(&"primary")

	_runner.assert_same(as_type_result, registration, "as_typeは同一登録オブジェクトを返す")
	_expect(registration.service_type == BaseService, "as_typeは公開型を更新する")
	_expect(with_key_result == registration, "with_keyは同一登録オブジェクトを返す")
	_expect(registration.key == &"primary", "with_keyは登録キーを更新する")


func _test_missing_types_and_invalid_lifecycle() -> void:
	_runner.change_test_name("missing_types_and_invalid_lifecycle")
	# 必須型の欠落と未知のライフサイクルを検証エラーとして報告します。
	var missing_implementation := _valid_registration()
	missing_implementation.implementation_type = null
	_expect_validation_error(missing_implementation, "生成するクラスが指定されていません")

	var missing_service := _valid_registration()
	missing_service.service_type = null
	_expect_validation_error(missing_service, "公開するクラスが指定されていません")

	var invalid_lifecycle := _valid_registration()
	# enum型の静的検査を迂回し、外部データなどから混入した不正な整数を再現します。
	invalid_lifecycle.set(&"lifecycle", 999)
	_expect_validation_error(invalid_lifecycle, "ライフサイクルが不正です: UNKNOWN(999)")


func _test_unnamed_type() -> void:
	_runner.change_test_name("unnamed_type")
	# Scriptそのものを解決キーに使うため、グローバルクラス名がない型も登録できます。
	var registration := ServiceRegistration.create_class_registration(
		UnnamedService,
		Lifecycle.Type.TRANSIENT,
	)
	var errors: PackedStringArray = registration.validate()

	_expect(errors.is_empty(), "class_nameのないScriptを正常な登録として扱う")
	_expect(registration.service_name.is_empty(), "class_nameのない公開型のサービス名は空になる")


func _test_unrelated_registration() -> void:
	_runner.change_test_name("unrelated_registration")
	# 実装型が公開型を継承していない組み合わせを検証エラーとして報告します。
	var registration := ServiceRegistration.create_class_registration(
		UnrelatedService,
		Lifecycle.Type.SINGLETON,
	).as_type(BaseService)

	_expect_validation_error(registration, "継承していません")


func _test_valid_registration() -> void:
	_runner.change_test_name("valid_registration")
	# class_name、継承関係、ライフサイクルが正しい登録には検証エラーがありません。
	var registration := _valid_registration()
	var errors: PackedStringArray = registration.validate()

	_expect(errors.is_empty(), "正常な登録のエラー配列が空になる")


func _test_lifecycle_helpers() -> void:
	_runner.change_test_name("lifecycle_helpers")
	# 全列挙値を有効と判定して名前へ変換し、列挙外の値はUNKNOWNとして扱います。
	_expect(Lifecycle.is_valid(Lifecycle.Type.SINGLETON), "SINGLETONを有効と判定する")
	_expect(Lifecycle.to_display_name(Lifecycle.Type.SINGLETON) == "SINGLETON", "SINGLETON名を返す")
	_expect(Lifecycle.is_valid(Lifecycle.Type.TRANSIENT), "TRANSIENTを有効と判定する")
	_expect(Lifecycle.to_display_name(Lifecycle.Type.TRANSIENT) == "TRANSIENT", "TRANSIENT名を返す")
	_expect(not Lifecycle.is_valid(999), "未知のライフサイクルを無効と判定する")
	_expect(Lifecycle.to_display_name(999) == "UNKNOWN(999)", "未知値を含む表示名を返す")


func _valid_registration() -> ServiceRegistration:
	# 各異常系テストの開始点となる、派生実装を基底型として公開する正常な登録です。
	return ServiceRegistration.create_class_registration(
		DerivedService,
		Lifecycle.Type.TRANSIENT,
	).as_type(BaseService).with_key(&"fixture")


func _expect_validation_error(
	registration: ServiceRegistration,
	expected_error: String,
) -> void:
	# validate()がエラーと期待するメッセージを返すことを確認します。
	var errors: PackedStringArray = registration.validate()

	_runner.assert_false(errors.is_empty(), "%s: 検証エラーを返す" % expected_error)
	_runner.assert_expected_error(
		errors,
		expected_error,
		"%s: 想定した検証エラーを返す" % expected_error,
	)


func _expect(condition: bool, message: String) -> void:
	_runner.assert_true(condition, message)
