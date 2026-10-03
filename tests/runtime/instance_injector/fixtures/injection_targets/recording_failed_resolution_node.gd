extends Node

var injection_count := 0


func inject_dependency(
	base_service: InstanceInjectorTestBaseService,
	unrelated_service: InstanceInjectorTestUnrelatedService,
) -> void:
	injection_count += 1
