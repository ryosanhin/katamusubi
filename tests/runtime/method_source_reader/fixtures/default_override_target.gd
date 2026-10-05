extends "base_target.gd"


## 非対応のオーバーライドから基底定義へ戻らないことを確認する。[br]
## [param manager]: デフォルト値を持つ依存[br]
## [param other]: デフォルト値を持つ依存
func inject_dependency(
		manager: Manager = null,
		other: MethodReaderTestDerivedService = null,
) -> void:
	pass
