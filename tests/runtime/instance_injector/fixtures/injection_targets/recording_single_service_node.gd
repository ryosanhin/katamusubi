extends Node

var injection_count := 0
var received_service: InstanceInjectorTestTrackedService
var was_injected := false


func inject_dependency(tracked_service: InstanceInjectorTestTrackedService) -> void:
	injection_count += 1
	received_service = tracked_service
	was_injected = true
