extends "inherited_target.gd"


## 子の定義が優先されることを確認する注入メソッド。[br]
## [param manager]: 基底で宣言した定数による依存[br]
## [param replacement]: 子の定義で名前を変更した依存
func inject_dependency(manager: Manager, replacement: MethodReaderTestDerivedService) -> void:
	pass
