extends RefCounted


# 末尾のデフォルト引数を含め宣言順を確認します。
func inject_dependency(
	_base_service: MethodReaderTestBaseService,
	_count: int,
	_display_name: String,
	_position: Vector2 = Vector2(1.0, 1.0),
	_derived_service: MethodReaderTestDerivedService = null,
) -> void:
	pass
