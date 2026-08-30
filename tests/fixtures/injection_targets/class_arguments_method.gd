extends RefCounted


# 末尾のデフォルト引数を含め、クラス型引数の宣言順を確認します。
func inject_dependency(
	base_service: TestBaseService,
	derived_service: TestDerivedService = null,
) -> void:
	pass
