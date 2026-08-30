class_name TestRunner
extends RefCounted


## falseにすると成功したアサーションの表示を省略します。
var show_passed_assertions := true
## 全テストの終了時にまとめて表示する失敗一覧です。
var failures: PackedStringArray = []

var _current_test := "(テスト名未設定)"


func begin_test(test_name: String) -> void:
	_current_test = test_name


func assert_true(actual: bool, message: String = "真である") -> void:
	_record(actual, message, true, actual)


func assert_false(actual: bool, message: String = "偽である") -> void:
	_record(not actual, message, false, actual)


func assert_equal(actual: Variant, expected: Variant, message: String = "等しい") -> void:
	_record(actual == expected, message, expected, actual)


func assert_not_equal(actual: Variant, unexpected: Variant, message: String = "等しくない") -> void:
	_record(actual != unexpected, message, "not %s" % _inspect(unexpected), actual)


func assert_same(actual: Variant, expected: Variant, message: String = "同一参照である") -> void:
	_record(is_same(actual, expected), message, expected, actual)


func assert_null(actual: Variant, message: String = "nullである") -> void:
	_record(actual == null, message, null, actual)


func assert_array(actual: Variant, expected: Array, message: String = "配列が等しい") -> void:
	var is_array := actual is Array or actual is PackedByteArray or actual is PackedInt32Array \
		or actual is PackedInt64Array or actual is PackedFloat32Array \
		or actual is PackedFloat64Array or actual is PackedStringArray \
		or actual is PackedVector2Array or actual is PackedVector3Array \
		or actual is PackedVector4Array or actual is PackedColorArray
	_record(is_array and Array(actual) == expected, message, expected, actual)


func assert_expected_error(
	actual_errors: Variant,
	expected_error: String,
	message: String = "期待したエラーを含む",
) -> void:
	var errors: Array[String] = []
	if actual_errors is String or actual_errors is StringName:
		errors.append(str(actual_errors))
	elif actual_errors is Array or actual_errors is PackedStringArray:
		for error in actual_errors:
			errors.append(str(error))
	var found := errors.any(func(error: String) -> bool: return expected_error in error)
	_record(found, message, expected_error, errors)


func finish(tree: SceneTree, suite_name: String) -> void:
	# 非同期処理が予約した最終フレームまで完了してから結果を集計します。
	await tree.process_frame
	if failures.is_empty():
		print("%s tests passed" % suite_name)
		tree.quit()
		return

	for failure in failures:
		push_error(failure)
	tree.quit(1)


func _record(passed: bool, message: String, expected: Variant, actual: Variant) -> void:
	if passed:
		if show_passed_assertions:
			print("[PASS] %s: %s" % [_current_test, message])
		return

	failures.append(
		"[FAIL] %s: %s\n  expected: %s\n  actual: %s"
		% [_current_test, message, _inspect(expected), _inspect(actual)],
	)


func _inspect(value: Variant) -> String:
	return var_to_str(value)
