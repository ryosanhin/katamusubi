@tool
extends ContainerScope

@export var test_manager: AbstactTestManager

func _register_instance(container: InjectionContainer) -> void:
	container.register(
			ServiceRegistration.create_instance_registration(
					test_manager,
					AbstactTestManager,
			)
	)
