extends Node

var injection_count := 0
var received_services: Array[InstanceInjectorTestBaseService] = []
var call_order: Array[StringName] = []
var was_injected := false


func inject_dependency(
	primary_service: InstanceInjectorTestBaseService,
	fallback_service: InstanceInjectorTestBaseService,
) -> void:
	injection_count += 1
	received_services.assign([primary_service, fallback_service])
	call_order.assign([&"primary_service", &"fallback_service", &"method_completed"])
	was_injected = true
