extends Node

var injection_count := 0
var received_services: Array[InstanceInjectorTestBaseService] = []


func inject_dependency(
	primary_service: InstanceInjectorTestBaseService,
	fallback_service: InstanceInjectorTestBaseService,
) -> void:
	injection_count += 1
	received_services.assign([primary_service, fallback_service])
