extends Node

var injection_count := 0
var received_services: Array[TestBaseService] = []
var call_order: Array[StringName] = []
var was_injected := false


func inject_dependency(
	primary_service: TestBaseService,
	fallback_service: TestBaseService,
) -> void:
	injection_count += 1
	received_services.assign([primary_service, fallback_service])
	call_order.assign([&"primary_service", &"fallback_service", &"method_completed"])
	was_injected = true
