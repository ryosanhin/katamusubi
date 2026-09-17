extends InjectionContainerTestBaseService
## コンテナが生成した回数と、各インスタンスを識別する番号を記録します。
class_name InjectionContainerTestTrackedService

static var generation_count := 0

var instance_id: int


func _init() -> void:
	generation_count += 1
	instance_id = generation_count


static func reset_generation_count() -> void:
	generation_count = 0
