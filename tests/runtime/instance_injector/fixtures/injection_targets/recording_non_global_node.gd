extends Node

const LocalService := preload("../services/unnamed_service.gd")

var injection_count := 0


func inject_dependency(_local_service: LocalService) -> void:
	injection_count += 1
