extends RefCounted
## 注入メソッドの宣言元を探し、引数名と型表記を取得する。
## 型名の解決・サービス型の検証・メソッド呼び出しは行わない。

const MethodSourceArgument := preload("method_source_argument.gd")
const MethodSourceResult := preload("method_source_result.gd")


## 対象から基底方向へ探索し、最初の定義を宣言元として解析する。[br]
## [param script]: 注入対象にアタッチされたScript[br]
## [param method_name]: 探索するメソッド名
static func read(script: Script, method_name: StringName) -> MethodSourceResult:
	var result := MethodSourceResult.new()
	result.method_name = method_name
	if script == null:
		result.error_code = MethodSourceResult.ErrorCode.MISSING_SCRIPT
		return result

	var declaration_pattern := RegEx.new()
	declaration_pattern.compile("(?m)^(?:static[ \\t]+)?func[ \\t]+([\\p{L}_][\\p{L}\\p{N}_]*)[ \\t]*\\(")
	var current := script
	while current != null:
		result.inspected_script = current
		if not current is GDScript:
			result.error_code = MethodSourceResult.ErrorCode.UNSUPPORTED_SCRIPT
			return result
		if not current.has_source_code():
			result.error_code = MethodSourceResult.ErrorCode.SOURCE_UNAVAILABLE
			return result

		var source := _mask_comments_and_strings(current.source_code)
		for declaration in declaration_pattern.search_all(source):
			if declaration.get_string(1) != String(method_name):
				continue
			result.declaring_script = current
			_parse_arguments(source, declaration.get_end(), result)
			return result
		current = current.get_base_script()

	result.error_code = MethodSourceResult.ErrorCode.MISSING_METHOD
	return result


## コメントと文字列を、位置と改行を維持したままマスクする。[br]
## [param source]: 探索するGDScriptソース
static func _mask_comments_and_strings(source: String) -> String:
	var masked := ""
	var index := 0
	while index < source.length():
		var character := source[index]
		if character == "#":
			while index < source.length() and source[index] != "\n":
				masked += " "
				index += 1
		elif character == "\"" or character == "'":
			var delimiter := character
			if source.substr(index, 3) == character.repeat(3):
				delimiter = character.repeat(3)
			# 引数中の文字列を空白として受理しないためのマーカー。
			masked += "~" + " ".repeat(delimiter.length() - 1)
			index += delimiter.length()
			while index < source.length():
				if source.substr(index, delimiter.length()) == delimiter:
					masked += " ".repeat(delimiter.length())
					index += delimiter.length()
					break
				if source[index] == "\\" and index + 1 < source.length():
					masked += " " + ("\n" if source[index + 1] == "\n" else " ")
					index += 2
				else:
					masked += "\n" if source[index] == "\n" else " "
					index += 1
		else:
			masked += character
			index += 1
	return masked


## 引数部分のみを解析し、全成功時に結果へ代入する。[br]
## [param source]: コメントと文字列をマスクしたソース[br]
## [param start]: 開き括弧の直後の位置[br]
## [param result]: 宣言元と失敗理由を保持する結果
static func _parse_arguments(source: String, start: int, result: MethodSourceResult) -> void:
	var end := source.find(")", start)
	if end == -1:
		result.error_code = MethodSourceResult.ErrorCode.INVALID_ARGUMENTS
		return
	var text := source.substr(start, end - start).strip_edges()
	if text.is_empty():
		return

	var identifier := "[\\p{L}_][\\p{L}\\p{N}_]*"
	var name_pattern := RegEx.new()
	name_pattern.compile("^" + identifier + "$")
	var arguments: Array[MethodSourceArgument] = []
	var names: Dictionary[StringName, bool] = {}
	var parts := text.split(",", true)
	for index in parts.size():
		var part := parts[index].strip_edges()
		if part.is_empty() and index == parts.size() - 1:
			continue
		var colon := part.find(":")
		var name := (
				part.substr(0, colon).strip_edges()
				if colon >= 0 else part.get_slice("=", 0).strip_edges()
		)
		result.arg_name = StringName(name) if name_pattern.search(name) != null else &""
		if "=" in part:
			result.error_code = MethodSourceResult.ErrorCode.DEFAULT_ARGUMENT
			return
		if part.is_empty() or result.arg_name.is_empty() or names.has(result.arg_name):
			result.error_code = MethodSourceResult.ErrorCode.INVALID_ARGUMENTS
			return
		if colon == -1:
			result.error_code = MethodSourceResult.ErrorCode.MISSING_TYPE_ANNOTATION
			return
		var type_name := part.substr(colon + 1).strip_edges()
		if name_pattern.search(type_name) == null:
			result.error_code = MethodSourceResult.ErrorCode.UNSUPPORTED_TYPE_NOTATION
			return
		arguments.append(MethodSourceArgument.new(result.arg_name, type_name))
		names[result.arg_name] = true

	result.arg_name = &""
	result.arguments = arguments
