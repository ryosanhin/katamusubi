extends SceneTree


const MethodReader := preload("res://addons/katamusubi/runtime/injection/method_reader.gd")
const ArgumentEntry := preload("res://addons/katamusubi/runtime/injection/argument_entry.gd")

const InstanceInjector := preload(
		"res://addons/katamusubi/runtime/injection/instance_injector.gd"
)

const BaseService := preload("fixtures/services/base_service.gd")
const DerivedService := preload("fixtures/services/derived_service.gd")

const NoInjectionMethod := preload("fixtures/injection_targets/no_injection_method.gd")
const ArgumentsMethod := preload("fixtures/injection_targets/arguments_method.gd")

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_missing_method()
	_test_class_arguments_and_defaults()

	await _runner.finish(self, "MethodReader")


## inject_dependencyメソッドを持たないスクリプトから空の引数一覧を取得することを確認します。
func _test_missing_method() -> void:
	_runner.change_test_name("missing_method")
	var arguments := _read(NoInjectionMethod)

	_runner.assert_true(arguments.is_empty(), "inject_dependencyがなければ空配列を返す")


## デフォルト値を含むクラス型引数を宣言順に読み取り、型情報を保持することを確認します。
func _test_class_arguments_and_defaults() -> void:
	_runner.change_test_name("class_arguments_and_defaults")
	var arguments := _read(ArgumentsMethod)

	_runner.assert_equal(arguments.size(), 5, "デフォルト引数を含むすべての引数を返す")
	_runner.assert_array(
		arguments.map(func(argument: ArgumentEntry) -> StringName: return argument.arg_name),
		[&"_base_service",&"_count", &"_display_name", &"_position", &"_derived_service"],
		"複数の引数を宣言順に返す",
	)
	_runner.assert_true(arguments[0].service_type == BaseService, "グローバルクラスのScriptを解決条件にする")
	_runner.assert_equal(arguments[0].arg_type, TYPE_OBJECT, "第1引数の型を保持する")
	_runner.assert_null(arguments[1].service_type, "組み込み型intにサービスScriptを設定しない")
	_runner.assert_equal(arguments[1].arg_type, TYPE_INT, "第1引数の型を保持する")
	_runner.assert_null(arguments[2].service_type, "組み込み型StringにサービスScriptを設定しない")
	_runner.assert_equal(arguments[2].arg_type, TYPE_STRING, "第2引数の型を保持する")
	_runner.assert_null(arguments[3].service_type, "組み込み型Vector2にサービスScriptを設定しない")
	_runner.assert_equal(arguments[3].arg_type, TYPE_VECTOR2, "第3引数の型を保持する")
	_runner.assert_true(arguments[4].service_type == DerivedService, "各グローバルクラスのScriptを保持する")
	_runner.assert_equal(arguments[4].arg_type, TYPE_OBJECT, "第2引数の型を保持する")


## MethodReaderを使って引数を取得
func _read(script: Script) -> Array[ArgumentEntry]:
	return MethodReader.new(InstanceInjector.INJECTION_METHOD_NAME).get_injection_arguments(script)
