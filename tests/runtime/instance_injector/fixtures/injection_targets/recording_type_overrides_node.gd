extends Node

const LocalService := preload("res://tests/runtime/instance_injector/fixtures/services/unnamed_service.gd")
const DerivedService := preload("res://tests/runtime/instance_injector/fixtures/services/derived_service.gd")
const UnrelatedService := preload("res://tests/runtime/instance_injector/fixtures/services/unrelated_service.gd")

var injection_count := 0
var received_local_service: LocalService
var received_derived_service: InstanceInjectorTestBaseService
var received_base_service: InstanceInjectorTestBaseService
var received_normal_service: InstanceInjectorTestBaseService


func get_inject_type_overrides() -> Dictionary[StringName, Script]:
	return {
		&"local_service": LocalService,
		&"derived_service": DerivedService,
		&"base_service": UnrelatedService,
	}


func inject_dependency(
	local_service: LocalService,
	derived_service: InstanceInjectorTestBaseService,
	base_service: InstanceInjectorTestBaseService,
	normal_service: InstanceInjectorTestBaseService,
) -> void:
	injection_count += 1
	received_local_service = local_service
	received_derived_service = derived_service
	received_base_service = base_service
	received_normal_service = normal_service
