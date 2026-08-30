extends SceneTree


const MethodReader := preload("res://addons/katamusubi/runtime/injection/method_reader.gd")
const ArgumentData := preload("res://addons/katamusubi/runtime/injection/argument_data.gd")
const Const := preload("res://addons/katamusubi/katamusubi_global.gd")
const NoInjectionMethod := preload(
	"res://tests/fixtures/injection_targets/no_injection_method.gd"
)
const NoArgumentMethod := preload(
	"res://tests/fixtures/injection_targets/no_argument_method.gd"
)
const ClassArgumentsMethod := preload(
	"res://tests/fixtures/injection_targets/class_arguments_method.gd"
)
const BuiltinArgumentsMethod := preload(
	"res://tests/fixtures/injection_targets/builtin_arguments_method.gd"
)
const AliasedMethod := preload(
	"res://tests/fixtures/injection_targets/aliased_method.gd"
)

var _runner := TestRunner.new(true)


func _init() -> void:
	_test_missing_method()
	_test_no_arguments()
	_test_class_arguments_and_defaults()
	_test_builtin_arguments()
	_test_aliased_method()
	_test_argument_data_string()

	await _runner.finish(self, "MethodReader")


func _test_missing_method() -> void:
	_runner.change_test_name("missing_method")
	var arguments := _read(NoInjectionMethod)

	_runner.assert_true(arguments.is_empty(), "inject_dependencyがなければ空配列を返す")


func _test_no_arguments() -> void:
	_runner.change_test_name("no_arguments")
	var arguments := _read(NoArgumentMethod)

	_runner.assert_true(arguments.is_empty(), "引数なしのinject_dependencyなら空配列を返す")


func _test_class_arguments_and_defaults() -> void:
	_runner.change_test_name("class_arguments_and_defaults")
	var arguments := _read(ClassArgumentsMethod)

	_runner.assert_equal(arguments.size(), 2, "デフォルト引数を含むすべての引数を返す")
	_runner.assert_array(
		arguments.map(func(argument: ArgumentData) -> StringName: return argument.arg_name),
		[&"base_service", &"derived_service"],
		"複数のクラス型引数を宣言順に返す",
	)
	_runner.assert_equal(arguments[0].arg_name, &"base_service", "第1引数の名前を保持する")
	_runner.assert_equal(arguments[0].arg_class, &"TestBaseService", "グローバルクラス名を解決条件にする")
	_runner.assert_equal(arguments[0].arg_type, TYPE_OBJECT, "第1引数の型を保持する")
	_runner.assert_equal(arguments[1].arg_name, &"derived_service", "第2引数の名前を保持する")
	_runner.assert_equal(arguments[1].arg_class, &"TestDerivedService", "各クラス型のグローバル名を保持する")
	_runner.assert_equal(arguments[1].arg_type, TYPE_OBJECT, "第2引数の型を保持する")


func _test_builtin_arguments() -> void:
	_runner.change_test_name("builtin_arguments")
	var arguments := _read(BuiltinArgumentsMethod)

	_runner.assert_equal(arguments.size(), 3, "すべての組み込み型引数を返す")
	_runner.assert_array(
		arguments.map(func(argument: ArgumentData) -> StringName: return argument.arg_name),
		[&"count", &"display_name", &"position"],
		"組み込み型引数を宣言順に返す",
	)
	_runner.assert_equal(arguments[0].arg_name, &"count", "第1引数の名前を保持する")
	_runner.assert_equal(arguments[0].arg_class, &"int", "intを解決条件にする")
	_runner.assert_equal(arguments[0].arg_type, TYPE_INT, "第1引数の型を保持する")
	_runner.assert_equal(arguments[1].arg_name, &"display_name", "第2引数の名前を保持する")
	_runner.assert_equal(arguments[1].arg_class, &"String", "Stringを解決条件にする")
	_runner.assert_equal(arguments[1].arg_type, TYPE_STRING, "第2引数の型を保持する")
	_runner.assert_equal(arguments[2].arg_name, &"position", "第3引数の名前を保持する")
	_runner.assert_equal(arguments[2].arg_class, &"Vector2", "Vector2を解決条件にする")
	_runner.assert_equal(arguments[2].arg_type, TYPE_VECTOR2, "第3引数の型を保持する")


func _test_aliased_method() -> void:
	_runner.change_test_name("aliased_method")
	var arguments := MethodReader.new(&"provide_dependencies").get_injection_arguments(AliasedMethod)

	_runner.assert_equal(arguments.size(), 2, "指定したメソッドの引数だけを返す")
	_runner.assert_array(
		arguments.map(func(argument: ArgumentData) -> StringName: return argument.arg_name),
		[&"service", &"enabled"],
		"コンストラクタで指定したメソッドだけを解析する",
	)
	_runner.assert_equal(arguments[0].arg_name, &"service", "第1引数の名前を保持する")
	_runner.assert_equal(arguments[0].arg_class, &"TestBaseService", "第1引数のクラス名を保持する")
	_runner.assert_equal(arguments[0].arg_type, TYPE_OBJECT, "第1引数の型を保持する")
	_runner.assert_equal(arguments[1].arg_name, &"enabled", "第2引数の名前を保持する")
	_runner.assert_equal(arguments[1].arg_class, &"bool", "第2引数のクラス名を保持する")
	_runner.assert_equal(arguments[1].arg_type, TYPE_BOOL, "第2引数の型を保持する")


func _test_argument_data_string() -> void:
	_runner.change_test_name("argument_data_string")
	var argument := ArgumentData.new(&"service", &"TestBaseService", TYPE_OBJECT)
	var description := str(argument)

	_runner.assert_true("service" in description, "文字列表現に引数名を含む")
	_runner.assert_true("TestBaseService" in description, "文字列表現にクラス名を含む")
	_runner.assert_true(str(TYPE_OBJECT) in description, "文字列表現に型番号を含む")
	_runner.assert_true(type_string(TYPE_OBJECT) in description, "文字列表現に型名を含む")


## MethodReaderを使って引数を取得
func _read(script: Script) -> Array[ArgumentData]:
	return MethodReader.new(Const.METHOD_NAME).get_injection_arguments(script)
