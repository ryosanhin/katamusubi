extends SceneTree


const BaseService := preload("res://tests/fixtures/services/base_service.gd")
const DerivedService := preload("res://tests/fixtures/services/derived_service.gd")
const UnrelatedService := preload("res://tests/fixtures/services/unrelated_service.gd")
const UnnamedService := preload("res://tests/fixtures/services/unnamed_service.gd")
const TestRunnerScript := preload("res://tests/support/test_runner.gd")

var _runner := TestRunnerScript.new()


func _init() -> void:
	# 公開APIの生成・更新、継承判定、検証、Lifecycleの全ケースを順番に確認します。
	_test_create_class_registration()
	_test_create_instance_registration()
	_test_fluent_updates()
	_test_valid_inheritance()
	_test_invalid_inheritance()
	_test_missing_types_and_invalid_lifecycle()
	_test_unnamed_types()
	_test_unrelated_registration()
	_test_valid_registration()
	_test_lifecycle_helpers()

	await _runner.finish(self, "ServiceRegistration")


func _test_create_class_registration() -> void:
	_runner.begin_test("create_class_registration")
	# クラス登録の生成時に実装型と公開型が一致し、指定した生成規則が保存されます。
	var registration := ServiceRegistration.create_class_registration(
		DerivedService,
		Lifecycle.Type.TRANSIENT,
	)

	_expect(registration.implementation_type == DerivedService, "クラス登録に実装型を設定する")
	_expect(registration.service_type == DerivedService, "クラス登録は実装型自身を公開する")
	_expect(registration.lifecycle == Lifecycle.Type.TRANSIENT, "指定したライフサイクルを設定する")


func _test_create_instance_registration() -> void:
	_runner.begin_test("create_instance_registration")
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


func _test_fluent_updates() -> void:
	_runner.begin_test("fluent_updates")
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


func _test_valid_inheritance() -> void:
	_runner.begin_test("valid_inheritance")
	# 同じ型は自分自身を満たし、派生実装は基底の公開契約を満たします。
	_expect(
		ServiceRegistration.check_inheritance(BaseService, BaseService),
		"実装型自身への継承判定が成功する",
	)
	_expect(
		ServiceRegistration.check_inheritance(DerivedService, BaseService),
		"派生型から基底型への継承判定が成功する",
	)


func _test_invalid_inheritance() -> void:
	_runner.begin_test("invalid_inheritance")
	# 無関係な型と、基底から派生という逆向きの判定はいずれも拒否されます。
	_expect(
		not ServiceRegistration.check_inheritance(UnrelatedService, BaseService),
		"無関係な型の継承判定が失敗する",
	)
	_expect(
		not ServiceRegistration.check_inheritance(BaseService, DerivedService),
		"逆方向の継承判定が失敗する",
	)


func _test_missing_types_and_invalid_lifecycle() -> void:
	_runner.begin_test("missing_types_and_invalid_lifecycle")
	# 必須型の欠落と未知のライフサイクルを拒否し、検証前の登録内容を維持します。
	var missing_implementation := _valid_registration()
	missing_implementation.implementation_type = null
	_expect_validation_rejected_without_mutation(missing_implementation, "生成するクラスが指定されていません")

	var missing_service := _valid_registration()
	missing_service.service_type = null
	_expect_validation_rejected_without_mutation(missing_service, "公開するクラスが指定されていません")

	var invalid_lifecycle := _valid_registration()
	# enum型の静的検査を迂回し、外部データなどから混入した不正な整数を再現します。
	invalid_lifecycle.set(&"lifecycle", 999)
	_expect_validation_rejected_without_mutation(invalid_lifecycle, "ライフサイクルが不正です: UNKNOWN(999)")


func _test_unnamed_types() -> void:
	_runner.begin_test("unnamed_types")
	# Godotのグローバルクラス名を持たないスクリプトは、実装型でも公開型でも拒否されます。
	var unnamed_implementation := _valid_registration()
	unnamed_implementation.implementation_type = UnnamedService
	_expect_validation_rejected_without_mutation(unnamed_implementation, "生成するクラスにはclass_nameが必要です")

	var unnamed_service := _valid_registration()
	unnamed_service.service_type = UnnamedService
	_expect_validation_rejected_without_mutation(unnamed_service, "公開するクラスにはclass_nameが必要です")


func _test_unrelated_registration() -> void:
	_runner.begin_test("unrelated_registration")
	# 実装型が公開型を継承していない組み合わせをエラーとして返し、登録自体は書き換えません。
	var registration := ServiceRegistration.create_class_registration(
		UnrelatedService,
		Lifecycle.Type.SINGLETON,
	).as_type(BaseService)

	_expect_validation_rejected_without_mutation(registration, "継承していません")


func _test_valid_registration() -> void:
	_runner.begin_test("valid_registration")
	# class_name、継承関係、ライフサイクルが正しい登録には検証エラーがありません。
	var registration := _valid_registration()
	var errors: PackedStringArray = registration.validate()

	_expect(errors.is_empty(), "正常な登録のエラー配列が空になる")


func _test_lifecycle_helpers() -> void:
	_runner.begin_test("lifecycle_helpers")
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


func _expect_validation_rejected_without_mutation(
	registration: ServiceRegistration,
	expected_error: String,
) -> void:
	# validate()の戻り値だけでなく、失敗しても入力した登録状態が変化しないことを比較します。
	var implementation_before = registration.implementation_type
	var service_before = registration.service_type
	var lifecycle_before = registration.lifecycle
	var instance_before = registration.instance
	var key_before = registration.key
	var errors: PackedStringArray = registration.validate()

	_runner.assert_false(errors.is_empty(), "%s: 検証エラーを返す" % expected_error)
	_runner.assert_expected_error(
		errors,
		expected_error,
		"%s: 想定した検証エラーを返す" % expected_error,
	)
	_expect(
		registration.implementation_type == implementation_before,
		"%s: 実装型を変更しない" % expected_error,
	)
	_expect(registration.service_type == service_before, "%s: 公開型を変更しない" % expected_error)
	_expect(registration.lifecycle == lifecycle_before, "%s: ライフサイクルを変更しない" % expected_error)
	_expect(registration.instance == instance_before, "%s: インスタンスを変更しない" % expected_error)
	_expect(registration.key == key_before, "%s: キーを変更しない" % expected_error)


func _expect(condition: bool, message: String) -> void:
	_runner.assert_true(condition, message)
