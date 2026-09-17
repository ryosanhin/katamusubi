extends Node

var override_value: Variant
var injection_count := 0


func get_inject_type_overrides() -> Variant:
	return override_value


func inject_dependency(service: InstanceInjectorTestBaseService) -> void:
	injection_count += 1
