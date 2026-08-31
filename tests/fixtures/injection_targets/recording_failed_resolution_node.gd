extends Node

var injection_count := 0
var was_injected := false


func inject_dependency(
	base_service: TestBaseService,
	unrelated_service: TestUnrelatedService,
) -> void:
	injection_count += 1
	was_injected = base_service != null and unrelated_service != null
