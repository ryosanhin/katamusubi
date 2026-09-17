extends RefCounted


# 末尾のデフォルト引数を含め、クラス型引数の宣言順を確認します。
func inject_dependency(
	base_service: MethodReaderTestBaseService,
	derived_service: MethodReaderTestDerivedService = null,
) -> void:
	pass
