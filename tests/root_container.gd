@tool
extends Katamusubi.ContainerScope

@export var test_manager: AbstractTestManager

func _register_instance(container: Katamusubi.InjectionContainer) -> void:
	container.register(
			Katamusubi.ServiceRegistration.create_instance_registration(
					test_manager,
					AbstractTestManager,
			)
	)
