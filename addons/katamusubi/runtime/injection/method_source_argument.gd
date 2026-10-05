extends RefCounted
## ソースに宣言された引数名と型表記。型名のScriptへの解決は別途行う。

var arg_name: StringName
var type_name: String


## 引数の表記を保持する。[br]
## [param init_arg_name]: 引数名[br]
## [param init_type_name]: 単一の識別子として記載された型名
func _init(init_arg_name: StringName, init_type_name: String) -> void:
	arg_name = init_arg_name
	type_name = init_type_name
