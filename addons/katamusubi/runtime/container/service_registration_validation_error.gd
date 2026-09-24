extends RefCounted
class_name ServiceRegistrationValidationError

## 登録検証エラーを、表示文言に依存せず識別するための安定したコードです。
enum Code {
	NULL_REGISTRATION,
	NULL_INSTANCE,
	INVALID_INSTANCE,
	MISSING_INSTANCE_SCRIPT,
	MISSING_IMPLEMENTATION_TYPE,
	INCOMPATIBLE_IMPLEMENTATION_TYPE,
	MISSING_SERVICE_TYPE,
	INCOMPATIBLE_SERVICE_TYPE,
}

## プログラムからエラーを識別するためのコード
var code: Code

## 診断やログへ表示する利用者向けメッセージ
var message: String


func _init(init_code: Code, init_message: String) -> void:
	code = init_code
	message = init_message
