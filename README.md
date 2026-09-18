# katamusubi
**A dependency injection container in GDScript.**

This project is heavily inspired by [VContainer](https://github.com/hadashiA/VContainer), an excellent DI library for C#. Therefore, the API and concepts intentionally resemble VContainer.

I realize that this is "reinventing the wheel" because Godot already has signals that can solve some part of dependency problems.

However, I hope this project will be useful to someone.

*English is not my first language so there may be some mistakes. Suggestions or corrections are always welcome. Thank you for your understanding!*

## How to use

### 1. Install the plugin

1. Copy the `addons/katamusubi` directory into your Godot project.
2. Open **Project > Project Settings > Plugins**.
3. Enable **katamusubi**.

### 2. Create a service

A service must have a global class name. For example, save this script as
`player_service.gd`:

```gdscript
extends RefCounted
class_name PlayerService

var player_name := "Player"
```

### 3. Create a container scope

Create a script that extends `ContainerScope`. Register your services in
`_register_instance()`:

```gdscript
extends ContainerScope

const PlayerServiceScript := preload("res://player_service.gd")


func _register_instance(container: InjectionContainer) -> void:
	container.register(
		ServiceRegistration.create_class_registration(
			PlayerServiceScript,
			Lifecycle.Type.SINGLETON,
		)
	)
```

Add a Node to your scene and attach this script. The plugin gives the scope an
ID when you save the scene.

The lifecycle controls how the service is created:

- `Lifecycle.Type.SINGLETON` creates one instance in the scope and reuses it.
- `Lifecycle.Type.TRANSIENT` creates a new instance for each request.

You can also register an instance that already exists:

```gdscript
func _register_instance(container: InjectionContainer) -> void:
	var service := PlayerService.new()
	container.register(
		ServiceRegistration.create_instance_registration(
			service,
			PlayerService,
		)
	)
```

### 4. Receive the service

Add an `inject_dependency()` method to a Node that needs the service. Add a
type to every argument:

```gdscript
extends Node

var _player_service: PlayerService


func inject_dependency(player_service: PlayerService) -> void:
	_player_service = player_service
```

Select the container scope in the Inspector. Add this Node to **Inject Target**.
The scope calls `inject_dependency()` when the scene is ready.

### Use a base type

Use `as_type()` when you want to receive a service through its base type:

```gdscript
container.register(
	ServiceRegistration.create_class_registration(
		PlayerService,
		Lifecycle.Type.SINGLETON,
	).as_type(BasePlayerService)
)
```

The argument type in `inject_dependency()` must be `BasePlayerService` in this
example.

### Register more than one service of the same type

Use `with_key()` to register more than one service of the same type. The key
must be the same as the argument name:

```gdscript
container.register(
	ServiceRegistration.create_class_registration(
		PlayerService,
		Lifecycle.Type.SINGLETON,
	).with_key(&"main_player")
)
```

```gdscript
func inject_dependency(main_player: PlayerService) -> void:
	_player_service = main_player
```

If there is no service with that key, katamusubi uses the service without a
key.

### Use parent and child scopes

Turn on **Selectable As Parent** for a scope that you want to share. Then select
that scope from **Current parent scope** in the child scope's Inspector.

A child scope can use services from its parent. If both scopes register the
same type and key, the child scope's service is used.
