extends Node

const Manager := preload("../../method_reader/fixtures/services/base_service.gd")


## 複数行と型名の読み取りに使う注入メソッド。[br]
## [param manager]: preload定数で型を指定した依存[br]
## [param other]: グローバルクラス名で型を指定した依存
func inject_dependency(
		manager: Manager, # 宣言元の定数
		other: MethodReaderTestDerivedService,
) -> void:
	pass
