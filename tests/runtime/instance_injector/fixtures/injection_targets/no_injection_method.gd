extends Node

var unrelated_call_count := 0
var override_call_count := 0

# 注入メソッドを宣言しない場合のリフレクション確認用です。
func unrelated_method() -> void:
	unrelated_call_count += 1


func get_inject_type_overrides() -> Dictionary:
	override_call_count += 1
	return {}
