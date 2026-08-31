extends Node

var injection_count := 0
var received_service: TestTrackedService
var was_injected := false


func inject_dependency(tracked_service: TestTrackedService) -> void:
	injection_count += 1
	received_service = tracked_service
	was_injected = true
