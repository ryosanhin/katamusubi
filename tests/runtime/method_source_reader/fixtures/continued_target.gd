extends "base_target.gd"


## 宣言と引数内に行継続を含むオーバーライド。[br]
## [param manager]: preload定数で型を指定した依存[br]
## [param other]: グローバルクラス名で型を指定した依存
func \
		inject_dependency\
		(\
		manager \
		: \
		Manager, \
		other: MethodReaderTestDerivedService,\
) -> void:
	pass
