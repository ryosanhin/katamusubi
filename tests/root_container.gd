@tool
extends ContainerScope

@export var test_manager: AbstractTestManager

func _register_instance(container: InjectionContainer) -> void:
	container.register(
			ServiceRegistration.create_instance_registration(
					test_manager,
					AbstractTestManager,
			)
	)
