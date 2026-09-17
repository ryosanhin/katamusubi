extends Node

const DerivedService := preload("res://tests/runtime/instance_injector/fixtures/services/derived_service.gd")

var injection_count := 0
var received_service: InstanceInjectorTestBaseService


func get_inject_type_overrides() -> Dictionary[StringName, Script]:
	return {&"overridden_service": DerivedService}


func inject_dependency(overridden_service: InstanceInjectorTestBaseService) -> void:
	injection_count += 1
	received_service = overridden_service
