extends Node


var unrelated_call_count := 0

# 注入メソッドを宣言しない場合のリフレクション確認用です。
func unrelated_method() -> void:
	unrelated_call_count += 1
