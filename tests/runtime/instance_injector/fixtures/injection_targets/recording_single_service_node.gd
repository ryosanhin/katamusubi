extends Node

var injection_count := 0
var received_service: InstanceInjectorTestTrackedService


func inject_dependency(tracked_service: InstanceInjectorTestTrackedService) -> void:
	injection_count += 1
	received_service = tracked_service
