extends RefCounted
## 注入対象として必要な状態を検証する

enum ErrorCode {
	OK,
	NULL_TARGET,
	FREED_TARGET,
	TARGET_OUTSIDE_TREE,
	MISSING_TARGET_SCRIPT,
}


## 最初の失敗理由と、説明文の生成に必要な補足情報。
class ValidationResult extends RefCounted:
	var error_code: ErrorCode = ErrorCode.OK
	var target_path: String
	var scope_name: StringName


	func is_valid() -> bool:
		return error_code == ErrorCode.OK


## 注入対象として必要な状態を検証する。
static func validate_target(target: Variant, scope_name: StringName) -> ValidationResult:
	var result := ValidationResult.new()
	result.scope_name = scope_name
	if typeof(target) == TYPE_NIL:
		result.error_code = ErrorCode.NULL_TARGET
		return result
	if not is_instance_valid(target):
		result.error_code = ErrorCode.FREED_TARGET
		return result
	if not target.is_inside_tree():
		result.target_path = str(target.name)
		result.error_code = ErrorCode.TARGET_OUTSIDE_TREE
		return result
	result.target_path = str(target.get_path())
	if target.get_script() == null:
		result.error_code = ErrorCode.MISSING_TARGET_SCRIPT
	return result


## 検証コードを人間向けの説明文へ変換する。検証処理自体は文字列に依存しない。
static func format_error(result: ValidationResult) -> String:
	match result.error_code:
		ErrorCode.OK:
			return ""
		ErrorCode.NULL_TARGET:
			return "対象が null です: スコープ名=%s" % result.scope_name
		ErrorCode.FREED_TARGET:
			return "対象は既に解放されています: スコープ名=%s" % result.scope_name
		ErrorCode.TARGET_OUTSIDE_TREE:
			return "対象はツリーに存在しません: 対象=%s, スコープ名=%s" % [result.target_path, result.scope_name]
		ErrorCode.MISSING_TARGET_SCRIPT:
			return "対象にスクリプトがありません: 対象=%s, スコープ名=%s" % [result.target_path, result.scope_name]

	return "不明な注入検証エラーです。"
