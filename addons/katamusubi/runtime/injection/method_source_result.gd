extends RefCounted
## 宣言元と引数の解析結果。失敗時には引数の部分結果を公開しない。

const MethodSourceArgument := preload("method_source_argument.gd")

enum ErrorCode {
	OK,
	MISSING_SCRIPT,
	UNSUPPORTED_SCRIPT,
	SOURCE_UNAVAILABLE,
	MISSING_METHOD,
	INVALID_ARGUMENTS,
	MISSING_TYPE_ANNOTATION,
	UNSUPPORTED_TYPE_NOTATION,
	DEFAULT_ARGUMENT,
}

var error_code: ErrorCode = ErrorCode.OK
var inspected_script: Script
var declaring_script: Script
var method_name: StringName
var arg_name: StringName
var arguments: Array[MethodSourceArgument] = []


## 宣言元の特定と全引数の解析が成功したかを返す。
func is_valid() -> bool:
	return error_code == ErrorCode.OK
